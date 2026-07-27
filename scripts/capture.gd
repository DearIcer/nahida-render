extends Node
# 截图工具：命令行带 --capture 时，等待若干帧后保存视口截图并退出
# 用法: godot -- --capture=res://screenshot.png

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--capture"):
			var path := "res://screenshot.png"
			if "=" in arg:
				path = arg.split("=", true, 1)[1]
			_capture(path)
			return

func _capture(path: String) -> void:
	for i in 45:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[capture] saved to ", path)
	get_tree().quit()
