use std::cell::RefCell;

use objc2::runtime::{AnyObject, NSObjectProtocol};
use objc2::{DefinedClass, MainThreadOnly, define_class, msg_send, rc::Retained, sel};
use objc2_app_kit::{
    NSAccessibility, NSImage, NSMenu, NSMenuItem, NSStatusBar, NSStatusItem,
    NSVariableStatusItemLength,
};
use objc2_foundation::{MainThreadMarker, NSObject, NSSize, NSString};

use crate::{host::Request, ui::Ui};

struct MenuActions {
    handle: rune::AppHandle<Ui>,
}

define_class!(
    #[unsafe(super = NSObject)]
    #[thread_kind = MainThreadOnly]
    #[ivars = MenuActions]
    struct TinyTypeMenuTarget;

    unsafe impl NSObjectProtocol for TinyTypeMenuTarget {}

    impl TinyTypeMenuTarget {
        #[unsafe(method(showTinyType:))]
        fn show(&self, _: &AnyObject) { self.ivars().handle.open(); }
        #[unsafe(method(toggleTinyType:))]
        fn toggle(&self, _: &AnyObject) { self.ivars().handle.update(|s, _| s.toggle_enabled()); }
        #[unsafe(method(undoTinyType:))]
        fn undo(&self, _: &AnyObject) { self.ivars().handle.update(|s, _| s.send(Request::Undo)); }
        #[unsafe(method(quitTinyType:))]
        fn quit(&self, _: &AnyObject) { self.ivars().handle.quit(); }
    }
);

thread_local! {
    static STATUS_ITEM: RefCell<Option<(Retained<NSStatusItem>, Retained<TinyTypeMenuTarget>)>> = const { RefCell::new(None) };
}

/// The native menu bar outlives the Rune settings window, as it does in Hex.
pub fn install(handle: rune::AppHandle<Ui>) {
    STATUS_ITEM.with(|stored| {
        if stored.borrow().is_some() {
            return;
        }
        let Some(mtm) = MainThreadMarker::new() else {
            return;
        };
        let target = TinyTypeMenuTarget::alloc(mtm).set_ivars(MenuActions { handle });
        // SAFETY: NSObject's designated initializer, on its required main thread.
        let target: Retained<TinyTypeMenuTarget> = unsafe { msg_send![super(target), init] };
        let menu = NSMenu::initWithTitle(NSMenu::alloc(mtm), &NSString::from_str("TinyType"));
        for (label, action) in [
            ("Open TinyType", sel!(showTinyType:)),
            ("Pause / resume autocorrect", sel!(toggleTinyType:)),
            ("Undo last correction", sel!(undoTinyType:)),
            ("Quit TinyType", sel!(quitTinyType:)),
        ] {
            // SAFETY: Each selector above is implemented by the retained target.
            let item = unsafe {
                NSMenuItem::initWithTitle_action_keyEquivalent(
                    NSMenuItem::alloc(mtm),
                    &NSString::from_str(label),
                    Some(action),
                    &NSString::new(),
                )
            };
            unsafe {
                item.setTarget(Some(&target));
            }
            menu.addItem(&item);
        }
        let item = NSStatusBar::systemStatusBar().statusItemWithLength(NSVariableStatusItemLength);
        if let Some(button) = item.button(mtm) {
            button.setToolTip(Some(&NSString::from_str("TinyType")));
            button.setAccessibilityLabel(Some(&NSString::from_str("TinyType")));
            // AppKit loads both bundled PNG scales and supplies the menu-bar tint.
            if let Some(image) = NSImage::imageNamed(&NSString::from_str("TinyFixTemplate")) {
                image.setSize(NSSize::new(18.0, 18.0));
                image.setTemplate(true);
                button.setImage(Some(&image));
            } else {
                button.setTitle(&NSString::from_str("Tt"));
            }
        }
        item.setMenu(Some(&menu));
        *stored.borrow_mut() = Some((item, target));
    });
}
