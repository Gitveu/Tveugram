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
    UserDefaults.standard.synchronize()
}

private final class TveugramSettingsControllerArguments {
    let updateCamera: (SlopgramVideoMessageCamera) -> Void
    let updateLocalPremium: (Bool) -> Void
    
    init(updateCamera: @escaping (SlopgramVideoMessageCamera) -> Void, updateLocalPremium: @escaping (Bool) -> Void) {
        self.updateCamera = updateCamera
        self.updateLocalPremium = updateLocalPremium
    }
}

private enum TveugramSettingsSection: Int32 {
    case premium
    case camera
}

private enum TveugramSettingsEntry: ItemListNodeEntry {
    case premiumHeader(PresentationTheme, String)
    case localPremium(PresentationTheme, String, Bool)
    case premiumInfo(PresentationTheme, String)
    case cameraHeader(PresentationTheme, String)
    case frontCamera(PresentationTheme, String, Bool)
    case backCamera(PresentationTheme, String, Bool)
    case cameraInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .premiumHeader, .localPremium, .premiumInfo:
                return TveugramSettingsSection.premium.rawValue
            case .cameraHeader, .frontCamera, .backCamera, .cameraInfo:
                return TveugramSettingsSection.camera.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .premiumHeader:
                return 0
            case .localPremium:
                return 1
            case .premiumInfo:
                return 2
            case .cameraHeader:
                return 3
            case .frontCamera:
                return 4
            case .backCamera:
                return 5
            case .cameraInfo:
                return 6
        }
    }
    
    static func ==(lhs: TveugramSettingsEntry, rhs: TveugramSettingsEntry) -> Bool {
        switch lhs {
            case let .premiumHeader(lhsTheme, lhsText):
                if case let .premiumHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .localPremium(lhsTheme, lhsText, lhsValue):
                if case let .localPremium(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .premiumInfo(lhsTheme, lhsText):
                if case let .premiumInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
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
    
    static func <(lhs: TveugramSettingsEntry, rhs: TveugramSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! TveugramSettingsControllerArguments
        switch self {
            case let .premiumHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .localPremium(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.updateLocalPremium(value)
                })
            case let .premiumInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
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

private func tveugramSettingsEntries(presentationData: PresentationData, camera: SlopgramVideoMessageCamera, localPremium: Bool) -> [TveugramSettingsEntry] {
    var entries: [TveugramSettingsEntry] = []
    
    let isRussian = presentationData.strings.baseLanguageCode.hasPrefix("ru")
    
    let premiumHeaderText = isRussian ? "ПРЕМИУМ" : "PREMIUM"
    let localPremiumText = isRussian ? "Локальный Premium" : "Local Premium"
    let premiumInfoText = isRussian ? "Активирует клиентские возможности Premium без реальной подписки: увеличенные лимиты на папки (до 100), закреплённые чаты (до 10), до 6 аккаунтов, бейдж в профиле и доступ к клиентской косметике." : "Enables client-side Premium features without a paid subscription: higher limits for folders (up to 100), pinned chats (up to 10), up to 6 accounts, profile badge, and client cosmetics."
    
    entries.append(.premiumHeader(presentationData.theme, premiumHeaderText))
    entries.append(.localPremium(presentationData.theme, localPremiumText, localPremium))
    entries.append(.premiumInfo(presentationData.theme, premiumInfoText))
    
    let cameraHeaderText = isRussian ? "КАМЕРА ДЛЯ ВИДЕОСООБЩЕНИЙ" : "VIDEO MESSAGE CAMERA"
    let frontText = isRussian ? "Фронтальная" : "Front"
    let backText = isRussian ? "Основная" : "Rear"
    let cameraInfoText = isRussian ? "Камера, которая будет использоваться по умолчанию при записи видеосообщений (кружков)." : "Choose which camera is used by default when recording video messages."
    
    entries.append(.cameraHeader(presentationData.theme, cameraHeaderText))
    entries.append(.frontCamera(presentationData.theme, frontText, camera == .front))
    entries.append(.backCamera(presentationData.theme, backText, camera == .back))
    entries.append(.cameraInfo(presentationData.theme, cameraInfoText))
    
    return entries
}

public func tveugramSettingsController(context: AccountContext) -> ViewController {
    let cameraPromise = ValuePromise<SlopgramVideoMessageCamera>(getSlopgramVideoMessageCamera(), ignoreRepeated: true)
    let localPremiumPromise = ValuePromise<Bool>(LocalPremium.isEnabled, ignoreRepeated: true)
    
    let arguments = TveugramSettingsControllerArguments(updateCamera: { option in
        setSlopgramVideoMessageCamera(option)
        cameraPromise.set(option)
    }, updateLocalPremium: { value in
        LocalPremium.isEnabled = value
        localPremiumPromise.set(value)
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, cameraPromise.get(), localPremiumPromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, camera, localPremium -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Tveugram"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: false
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: tveugramSettingsEntries(presentationData: presentationData, camera: camera, localPremium: localPremium),
            style: .blocks,
            emptyStateItem: nil,
            animateChanges: false
        )
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    return controller
}

public func slopgramSettingsController(context: AccountContext) -> ViewController {
    return tveugramSettingsController(context: context)
}
