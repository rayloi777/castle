package js.node.webkit;

import js.jquery.Event;

@:expose
class MenuItem {
	public var type(default, null): MenuItemType;
	public var label: String;
	public var icon: String;
	public var tooltip: String;
	public var checked: Bool;
	public var enabled: Bool;
	public var submenu: Menu;

	public var click: Event -> Void;

	public function new(?t: { ?label: String, ?icon: String, ?type: MenuItemType, ?key: String, ?modifiers: String }): Void {
		if (t != null) {
			label = t.label;
			icon = t.icon;
			type = t.type;
		}
		if (enabled == null) enabled = true;
	}

	public function on(event: String, callb: Void -> Void): Void {
		// Browser doesn't support menu item events the same way
	}
}
