package js.node.webkit;

@:expose
@:enum abstract MenuItemType(String) {
	var separator = "separator";
	var checkbox = "checkbox";
	var normal = "normal";
}
