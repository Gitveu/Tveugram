import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext

public enum SlopgramVideoMessageCamera: String {
    case front = "front"
    case back = "back"
}

public func getSlopgramVideoMessageCamera() -> SlopgramVideoMessageCamera {
    if let val = UserDefaults.standard.string(forKey: "slopgram_video_message_camera"),
       let camera = SlopgramVideoMessageCamera(rawValue: val) {
        return camera
    }
    return .front
}

public func setSlopgramVideoMessageCamera(_ camera: SlopgramVideoMessageCamera) {
    UserDefaults.standard.set(camera.rawValue, forKey: "slopgram_video_message_camera")
}

private final class SlopgramSettingsControllerArguments {
    let updateCamera: (SlopgramVideoMessageCamera) -> Void
    
    init(updateCamera: @escaping (SlopgramVideoMessageCamera) -> Void) {
        self.updateCamera = updateCamera
    }
}

private enum SlopgramSettingsSection: Int32 {
    case camera
}

private enum SlopgramSettingsEntry: ItemListNodeEntry {
    case cameraHeader(PresentationTheme, String)
    case frontCamera(PresentationTheme, String, Bool)
    case backCamera(PresentationTheme, String, Bool)
    case cameraInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        return SlopgramSettingsSection.camera.rawValue
    }
    
    var stableId: Int32 {
        switch self {
            case .cameraHeader:
                return 0
            case .frontCamera:
                return 1
            case .backCamera:
                return 2
            case .cameraInfo:
                return 3
        }
    }
    
    static func ==(lhs: SlopgramSettingsEntry, rhs: SlopgramSettingsEntry) -> Bool {
        switch lhs {
            case let .cameraHeader(lhsTheme, lhsText):
                if case let .cameraHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .frontCamera(lhsTheme, lhsText, lhsValue):
                if case let .frontCamera(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .backCamera(lhsTheme, lhsText, lhsValue):
                if case let .backCamera(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .cameraInfo(lhsTheme, lhsText):
                if case let .cameraInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: SlopgramSettingsEntry, rhs: SlopgramSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! SlopgramSettingsControllerArguments
        switch self {
            case let .cameraHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .frontCamera(_, text, value):
                return ItemListCheckboxItem(presentationData: presentationData, title: text, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateCamera(.front)
                })
            case let .backCamera(_, text, value):
                return ItemListCheckboxItem(presentationData: presentationData, title: text, style: .left, checked: value, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateCamera(.back)
                })
            case let .cameraInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func slopgramSettingsEntries(presentationData: PresentationData, camera: SlopgramVideoMessageCamera) -> [SlopgramSettingsEntry] {
    var entries: [SlopgramSettingsEntry] = []
    
    let isRussian = presentationData.strings.baseLanguageCode.hasPrefix("ru")
    let headerText = isRussian ? "КАМЕРА ДЛЯ ВИДЕОСООБЩЕНИЙ" : "VIDEO MESSAGE CAMERA"
    let frontText = isRussian ? "Фронтальная" : "Front"
    let backText = isRussian ? "Основная" : "Rear"
    let infoText = isRussian ? "Камера, которая будет использоваться по умолчанию при записи видеосообщений (кружков)." : "Choose which camera is used by default when recording video messages."
    
    entries.append(.cameraHeader(presentationData.theme, headerText))
    entries.append(.frontCamera(presentationData.theme, frontText, camera == .front))
    entries.append(.backCamera(presentationData.theme, backText, camera == .back))
    entries.append(.cameraInfo(presentationData.theme, infoText))
    
    return entries
}

public func slopgramSettingsController(context: AccountContext) -> ViewController {
    let cameraPromise = ValuePromise<SlopgramVideoMessageCamera>(getSlopgramVideoMessageCamera(), ignoreRepeated: true)
    
    let arguments = SlopgramSettingsControllerArguments(updateCamera: { option in
        setSlopgramVideoMessageCamera(option)
        cameraPromise.set(option)
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, cameraPromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, camera -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Slopgram"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: false
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: slopgramSettingsEntries(presentationData: presentationData, camera: camera),
            style: .blocks,
            emptyStateItem: nil,
            animateChanges: false
        )
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    return controller
}
