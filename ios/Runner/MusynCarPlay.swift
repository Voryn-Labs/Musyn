import CarPlay
import Flutter
import UIKit

@MainActor final class MusynCarPlay {
  static let shared = MusynCarPlay()
  private var channel: FlutterMethodChannel?
  private weak var controller: CPInterfaceController?
  private var lists: [String: CPListTemplate] = [:]
  private var epoch = -1
  private var generation = 0
  private var selection = 0

  func configure(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "com.vorynlabs.musyn/carplay", binaryMessenger: messenger)
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(false); return }
      if call.method == "ready" { result(self.controller != nil); return }
      guard call.method == "setState", let args = call.arguments as? [String: Any],
        let next = args["epoch"] as? Int, next >= self.epoch,
        let sections = args["sections"] as? [[String: Any]] else { result(FlutterMethodNotImplemented); return }
      self.epoch = next
      self.update(sections)
      result(nil)
    }
  }

  func connect(_ controller: CPInterfaceController) {
    self.controller = controller
    generation += 1
    let categories = [("current_queue", "Queue", "list.bullet"), ("offline_songs", "Downloads", "arrow.down.circle"),
                      ("liked_songs", "Favorites", "heart"), ("recently_played", "Recent", "clock")]
    let templates = categories.map { id, title, symbol -> CPListTemplate in
      let list = CPListTemplate(title: title, sections: [])
      list.emptyViewTitleVariants = ["Opening your library"]
      list.emptyViewSubtitleVariants = ["Musyn · Voryn Labs"]
      list.tabTitle = title; list.tabImage = UIImage(systemName: symbol)
      let nowPlaying = CPBarButton(type: .text) { [weak self] _ in
        self?.showNowPlaying()
      }
      nowPlaying.title = "Now Playing"
      list.trailingNavigationBarButtons = [nowPlaying]
      lists[id] = list
      return list
    }
    controller.setRootTemplate(CPTabBarTemplate(templates: templates), animated: false, completion: nil)
    channel?.invokeMethod("connection", arguments: true)
  }

  func disconnect() {
    generation += 1
    controller = nil
    lists.removeAll()
    channel?.invokeMethod("connection", arguments: false)
  }

  private func showNowPlaying() {
    guard let controller = controller, controller.topTemplate !== CPNowPlayingTemplate.shared else { return }
    controller.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
  }

  private func update(_ sections: [[String: Any]]) {
    guard controller != nil else { return }
    let connection = generation
    for section in sections.prefix(4) {
      guard let id = section["id"] as? String, let list = lists[id], let rows = section["items"] as? [[String: Any]] else { continue }
      let items: [CPListItem] = rows.prefix(100).compactMap { row in
        guard let mediaID = row["id"] as? String, let title = row["title"] as? String else { return nil }
        let item = CPListItem(text: title, detailText: row["artist"] as? String)
        item.isPlaying = row["playing"] as? Bool ?? false
        item.handler = { [weak self] _, complete in
          guard let self = self, self.generation == connection, let channel = self.channel else { complete(); return }
          self.selection += 1
          let selection = self.selection
          // Complete the car's row immediately; playback resolves through the
          // existing latest-selection-wins transaction on the shared player.
          complete()
          channel.invokeMethod("play", arguments: ["category": id, "id": mediaID]) { [weak self] response in
            guard let self = self, self.generation == connection, self.selection == selection else { return }
            if response as? Bool == true { self.showNowPlaying() }
            else { self.showError() }
          }
        }
        return item
      }
      list.emptyViewTitleVariants = ["No music here yet"]
      list.emptyViewSubtitleVariants = ["Add music in Musyn on your iPhone"]
      list.updateSections(items.isEmpty ? [] : [CPListSection(items: items)])
    }
  }

  private func showError() {
    guard let controller = controller, controller.presentedTemplate == nil else { return }
    let close = CPAlertAction(title: "OK", style: .default) { [weak controller] _ in
      controller?.dismissTemplate(animated: true, completion: nil)
    }
    controller.presentTemplate(CPAlertTemplate(titleVariants: ["That song is unavailable. Try another selection."], actions: [close]), animated: true, completion: nil)
  }
}

class MusynCarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
  func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
    MusynCarPlay.shared.connect(interfaceController)
  }
  func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) {
    MusynCarPlay.shared.disconnect()
  }
}
