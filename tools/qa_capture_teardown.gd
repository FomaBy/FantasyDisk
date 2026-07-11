extends RefCounted

## Shared lifecycle barrier for windowed QA capture fixtures.
##
## Production nodes remain untouched: the helper only owns fixture viewports
## and calls AudioManager's public stop_music API before SceneTree shutdown.


func release_viewport(tree: SceneTree, owned_viewport: SubViewport) -> PackedStringArray:
	var errors := PackedStringArray()
	if owned_viewport == null or not is_instance_valid(owned_viewport):
		return errors
	owned_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var child_refs: Array[WeakRef] = []
	for child in owned_viewport.get_children():
		child_refs.append(weakref(child))
		child.queue_free()
	for _frame_index in range(3):
		await tree.process_frame
	for child_ref in child_refs:
		if child_ref.get_ref() != null:
			errors.append("QA capture teardown retained an owned SubViewport child after the deferred-free barrier.")
	var viewport_ref: WeakRef = weakref(owned_viewport)
	owned_viewport.queue_free()
	for _frame_index in range(4):
		await tree.process_frame
	if viewport_ref.get_ref() != null:
		errors.append("QA capture teardown retained its owned SubViewport after the deferred-free barrier.")
	await tree.process_frame
	return errors


func release_windowed_audio(tree: SceneTree) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var audio := tree.root.get_node_or_null("AudioManager")
	if audio != null and audio.has_method("stop_music"):
		audio.call("stop_music")
	# Metal's audio thread may still own the Ogg packet/playback chain for a few
	# frames after AudioStreamPlayer.stop + stream=null. Do not quit before that
	# ownership barrier has drained.
	for _frame_index in range(8):
		await tree.process_frame
