//
//  TouchscreenMouseEventAdapter.swift
//  PlayTools
//
//  Created by 许沂聪 on 2023/9/16.
//

import Foundation
import CoreGraphics

// Mouse events handler when cursor is free and keyboard mapping is on

public class TouchscreenMouseEventAdapter: MouseEventAdapter {

    static public func cursorPos() -> CGPoint? {
        guard let host = AKInterface.shared, let window = screen.keyWindow else { return nil }
        let point = host.mousePoint
        let contentSize = host.windowContentSize
        guard contentSize.width > 0, contentSize.height > 0,
              point.x >= 0, point.y >= 0,
              point.x <= contentSize.width, point.y <= contentSize.height else { return nil }
        if screen.resizable && !screen.fullscreen {
            // Let AppKit handle dragging the window edges.
            let margin = CGFloat(10)
            if point.x < margin || point.x > contentSize.width - margin ||
                point.y < margin || point.y > contentSize.height - margin {
                return nil
            }
        }
        // UIScreen can retain portrait bounds after the window rotates. Touches
        // are delivered in UIWindow coordinates, scaled from the host content.
        let bounds = window.bounds
        return CGPoint(x: bounds.minX + point.x * bounds.width / contentSize.width,
                       y: bounds.maxY - point.y * bounds.height / contentSize.height)
    }

    public func handleScrollWheel(deltaX: CGFloat, deltaY: CGFloat) -> Bool {
        _ = ActionDispatcher.dispatch(key: KeyCodeNames.scrollWheelDrag, valueX: deltaX, valueY: deltaY)
        // I dont know why but this is the logic before the refactor.
        // Might be a mistake but keeping it for now
        return false
    }

    public func handleMove(deltaX: CGFloat, deltaY: CGFloat) -> Bool {
        if ActionDispatcher.getDispatchPriority(key: KeyCodeNames.mouseMove) == .DRAGGABLE {
            // condition meets when draggable button pressed
            return ActionDispatcher.dispatch(key: KeyCodeNames.mouseMove, valueX: deltaX, valueY: -deltaY)
        } else if ActionDispatcher.getDispatchPriority(key: KeyCodeNames.fakeMouse) == .DRAGGABLE {
            // condition meets when mouse pressed and draggable button not pressed
            // fake mouse handler priority:
            // default direction pad: press handler
            // draggable direction pad: move handler
            // default button: lift handler
            // kinda hacky but.. IT WORKS!
            guard let pos = TouchscreenMouseEventAdapter.cursorPos() else { return false }
            return ActionDispatcher.dispatch(key: KeyCodeNames.fakeMouse, valueX: pos.x, valueY: pos.y)

        }
        return false
    }

    public func handleLeftButton(pressed: Bool) -> Bool {
        // It is necessary to calculate pos before pushing to dispatch queue
        // Otherwise, we don't know whether to return false or true
        guard let pos = TouchscreenMouseEventAdapter.cursorPos() else { return false }
        if pressed {
            return ActionDispatcher.dispatch(key: KeyCodeNames.fakeMouse, valueX: pos.x, valueY: pos.y)
        } else {
            return ActionDispatcher.dispatch(key: KeyCodeNames.fakeMouse, pressed: pressed)
        }
    }

    public func handleOtherButton(id: Int, pressed: Bool) -> Bool {
        ActionDispatcher.dispatch(key: EditorMouseEventAdapter.getMouseButtonName(id),
                                  pressed: pressed)
    }

    public func cursorHidden() -> Bool {
        false
    }

}
