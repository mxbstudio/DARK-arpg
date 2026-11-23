extends Node
## Procedurally synthesized placeholder sounds (no external assets, no license issues).
## Gameplay-relevant sounds are positional (AudioStreamPlayer2D) so direction and
## distance can be read by ear. Sounds behind walls are muffled (quieter).

signal loading_progress(fraction: float)
signal finished_loading

const RATE := 22050
const WALL_MASK := 1

var loaded := false
var _cache: Dictionary = {}  # name -> Array of AudioStreamWAV variants
var _rng := RandomNumberGenerator.new()
var _occluded_db := -9.0


func _ready() -> void:
	_rng.randomize()
	_occluded_db = float(Balance.section("audio")["occluded_db"])
	_synthesize()


## Synthesizes all sounds, yielding a frame between them so the page/window stays
## responsive (important on slow web/mobile runtimes). Emits `finished_loading` when done.
func _synthesize() -> void:
	var growl_len := float(Balance.section("enemies")["ghoul"]["windup"])
	var jobs: Array[Array] = [
		["step_soft", _step_soft, 3],
		["step_plate", _step_plate, 3],
		["enemy_step", _enemy_step, 3],
		["breath", _breath, 2],
		["growl", _growl.bind(growl_len, true), 2],
		["alert", _growl.bind(0.35, false), 2],
		["swing", _swing, 2],
		["hit", _hit.bind(85.0, 500.0), 1],
		["hit", _hit.bind(95.0, 550.0), 1],
		["player_hurt", _hit.bind(120.0, 900.0), 1],
		["enemy_death", _enemy_death, 1],
		["dodge", _dodge, 2],
		["descend", _descend, 1],
		["wind", _wind, 1],
		["drone", _drone, 1],
		["fire", _fire, 1],
	]
	for idx in jobs.size():
		var job := jobs[idx]
		var maker: Callable = job[1]
		for i in int(job[2]):
			if not _cache.has(job[0]):
				_cache[job[0]] = []
			(_cache[job[0]] as Array).append(maker.call())
		loading_progress.emit(float(idx + 1) / jobs.size())
		await get_tree().process_frame
	loaded = true
	finished_loading.emit()


## Returns a random variant of a named sound.
func stream(sound: String) -> AudioStreamWAV:
	var list: Array = _cache.get(sound, [])
	if list.is_empty():
		push_warning("Sfx: unknown sound '%s'" % sound)
		return null
	return list[_rng.randi() % list.size()]


## Plays a one-shot at a fixed world position (stays there).
func play_at(sound: String, pos: Vector2, parent: Node2D, volume_db := 0.0, max_distance := 600.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := _make_player(sound, volume_db, max_distance)
	if p == null:
		return
	parent.add_child(p)
	p.global_position = pos
	p.volume_db += _occlusion_db(pos, parent)
	p.play()


## Plays a one-shot attached to a node (follows it while it moves).
func play_on(sound: String, node: Node2D, volume_db := 0.0, max_distance := 600.0) -> void:
	if node == null or not node.is_inside_tree():
		return
	var p := _make_player(sound, volume_db, max_distance)
	if p == null:
		return
	node.add_child(p)
	p.volume_db += _occlusion_db(node.global_position, node)
	p.play()


## Non-positional sound (UI, transitions).
func play_ui(sound: String, volume_db := 0.0) -> void:
	var s := stream(sound)
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = volume_db
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()


func _make_player(sound: String, volume_db: float, max_distance: float) -> AudioStreamPlayer2D:
	var s := stream(sound)
	if s == null:
		return null
	var p := AudioStreamPlayer2D.new()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = _rng.randf_range(0.92, 1.08)
	p.max_distance = max_distance
	p.attenuation = 1.6
	p.finished.connect(p.queue_free)
	return p


func _occlusion_db(pos: Vector2, ctx: Node2D) -> float:
	var cam := ctx.get_viewport().get_camera_2d()
	if cam == null:
		return 0.0
	var query := PhysicsRayQueryParameters2D.create(cam.get_screen_center_position(), pos, WALL_MASK)
	var hit := ctx.get_world_2d().direct_space_state.intersect_ray(query)
	return _occluded_db if not hit.is_empty() else 0.0


# --- synthesis helpers -------------------------------------------------------

func _buf(duration: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(duration * RATE))
	return b


func _noise() -> float:
	return _rng.randf_range(-1.0, 1.0)


## One-pole lowpass coefficient for cutoff `fc` in Hz.
func _lp(fc: float) -> float:
	return 1.0 - exp(-TAU * fc / RATE)


func _to_wav(samples: PackedFloat32Array, peak := 0.85, loop := false) -> AudioStreamWAV:
	var m := 0.0
	for v in samples:
		m = maxf(m, absf(v))
	var k := peak / m if m > 0.0 else 1.0
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i] * k, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


# --- sounds -----------------------------------------------------------------

func _step_soft() -> AudioStreamWAV:
	var b := _buf(0.12)
	var lp := 0.0
	var a := _lp(_rng.randf_range(450.0, 700.0))
	var thump := _rng.randf_range(90.0, 130.0)
	for i in b.size():
		var t := float(i) / RATE
		lp += a * (_noise() - lp)
		b[i] = lp * exp(-t * 40.0) * 2.0 + sin(TAU * thump * t) * exp(-t * 60.0) * 0.5
	return _to_wav(b, 0.7)


func _step_plate() -> AudioStreamWAV:
	var b := _buf(0.45)
	var base := _rng.randf_range(850.0, 1150.0)
	var partials: Array[float] = [1.0, 1.52, 2.27, 2.93, 3.71]
	var lp := 0.0
	var a := _lp(600.0)
	for i in b.size():
		var t := float(i) / RATE
		lp += a * (_noise() - lp)
		var clank := 0.0
		for k in partials.size():
			clank += sin(TAU * base * partials[k] * t + k) * exp(-t * (9.0 + k * 5.0)) / (1.0 + k * 0.6)
		var rattle := _noise() * exp(-t * 18.0) * 0.25 * (0.5 + 0.5 * sin(TAU * 31.0 * t))
		b[i] = lp * exp(-t * 40.0) * 1.6 + clank * 0.5 + rattle
	return _to_wav(b, 0.85)


func _enemy_step() -> AudioStreamWAV:
	var b := _buf(0.22)
	var lp := 0.0
	var a := _lp(250.0)
	var lp2 := 0.0
	var a2 := _lp(2500.0)
	var f0 := _rng.randf_range(55.0, 75.0)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / RATE
		phase += TAU * f0 * (1.0 - t * 1.5) / RATE
		var n := _noise()
		lp += a * (n - lp)
		lp2 += a2 * (n - lp2)
		var thud := (sin(phase) * 0.9 + lp * 2.5) * exp(-t * 28.0)
		# Claws scraping over stone right after the impact.
		var scrape_env := clampf((t - 0.04) * 30.0, 0.0, 1.0) * exp(-maxf(t - 0.04, 0.0) * 22.0)
		b[i] = thud + (n - lp2) * scrape_env * 0.35
	return _to_wav(b, 0.85)


func _breath() -> AudioStreamWAV:
	var b := _buf(1.6)
	var lo := 0.0
	var hi := 0.0
	var a_lo := _lp(1200.0)
	var a_hi := _lp(300.0)
	var wheeze_f := _rng.randf_range(380.0, 520.0)
	for i in b.size():
		var t := float(i) / RATE
		var n := _noise()
		lo += a_lo * (n - lo)
		hi += a_hi * (n - hi)
		var env := 0.0
		if t < 0.7:
			env = sin(PI * t / 0.7) * 0.6
		elif t > 0.8:
			env = sin(PI * (t - 0.8) / 0.8)
		var rasp := 0.6 + 0.4 * sin(TAU * 23.0 * t)
		b[i] = (lo - hi) * env * rasp * 3.0 + sin(TAU * wheeze_f * t) * 0.08 * env
	return _to_wav(b, 0.8)


## Crescendo growl = attack telegraph: it peaks exactly when the attack lands.
func _growl(duration: float, crescendo: bool) -> AudioStreamWAV:
	var b := _buf(duration)
	var lp := 0.0
	var a := _lp(800.0)
	var phase := 0.0
	var f0 := _rng.randf_range(65.0, 85.0)
	for i in b.size():
		var t := float(i) / RATE
		var u := t / duration
		var f := f0 * (1.0 + 0.08 * sin(TAU * 5.5 * t)) * (1.0 + (0.35 * u if crescendo else 0.0))
		phase += f / RATE
		var saw := 2.0 * (phase - floorf(phase)) - 1.0
		lp += a * (saw * (1.0 + 0.5 * _noise()) - lp)
		var env := sin(PI * u)
		if crescendo:
			env = pow(u, 1.4) * clampf((1.0 - u) * 25.0, 0.0, 1.0)
		b[i] = lp * env
	return _to_wav(b, 0.9)


func _swing() -> AudioStreamWAV:
	var b := _buf(0.24)
	var lp := 0.0
	for i in b.size():
		var u := float(i) / b.size()
		var bell := sin(PI * u)
		lp += _lp(300.0 + 2600.0 * bell * bell) * (_noise() - lp)
		b[i] = lp * bell
	return _to_wav(b, 0.6)


func _hit(thump_f: float, cutoff: float) -> AudioStreamWAV:
	var b := _buf(0.25)
	var lp := 0.0
	var a := _lp(cutoff)
	for i in b.size():
		var t := float(i) / RATE
		var n := _noise()
		lp += a * (n - lp)
		b[i] = lp * exp(-t * 22.0) * 2.5 + sin(TAU * thump_f * t) * exp(-t * 18.0) * 0.8 + n * exp(-t * 90.0) * 0.4
	return _to_wav(b, 0.9)


func _enemy_death() -> AudioStreamWAV:
	var b := _buf(1.3)
	var lp := 0.0
	var a := _lp(600.0)
	var lp2 := 0.0
	var a2 := _lp(200.0)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := lerpf(110.0, 35.0, minf(t / 0.9, 1.0))
		phase += f / RATE
		var saw := 2.0 * (phase - floorf(phase)) - 1.0
		var n := _noise()
		lp += a * (saw * (1.0 + 0.6 * n) - lp)
		lp2 += a2 * (n - lp2)
		var voice := lp * exp(-t * 2.5) * (1.0 if t < 0.9 else 0.0)
		var fall := lp2 * 4.0 * exp(-maxf(t - 0.95, 0.0) * 14.0) * (1.0 if t > 0.95 else 0.0)
		b[i] = voice + fall
	return _to_wav(b, 0.85)


func _dodge() -> AudioStreamWAV:
	var b := _buf(0.2)
	var lp := 0.0
	var a := _lp(1500.0)
	for i in b.size():
		var u := float(i) / b.size()
		lp += a * (_noise() - lp)
		b[i] = lp * sin(PI * u)
	return _to_wav(b, 0.5)


func _descend() -> AudioStreamWAV:
	var b := _buf(1.8)
	var lo := 0.0
	var mid := 0.0
	var a_lo := _lp(120.0)
	var a_mid := _lp(900.0)
	for i in b.size():
		var t := float(i) / RATE
		var n := _noise()
		lo += a_lo * (n - lo)
		mid += a_mid * (n - mid)
		var env := sin(PI * t / 1.8)
		b[i] = (lo * 5.0 + mid * 0.6 * (0.5 + 0.5 * sin(TAU * 13.0 * t))) * env
	return _to_wav(b, 0.8)


## Cold draft from the stairs down. Loop length chosen so modulations wrap cleanly.
func _wind() -> AudioStreamWAV:
	var b := _buf(4.0)
	var lp := 0.0
	for i in b.size():
		var t := float(i) / RATE
		lp += _lp(300.0 + 250.0 * sin(TAU * 0.5 * t)) * (_noise() - lp)
		var amp := 0.6 + 0.4 * sin(TAU * 0.25 * t)
		var whistle := sin(TAU * 610.0 * t) * 0.03 * (0.5 + 0.5 * sin(TAU * 0.75 * t))
		b[i] = lp * amp * 3.0 + whistle
	return _to_wav(b, 0.7, true)


func _drone() -> AudioStreamWAV:
	var b := _buf(6.0)
	var lp := 0.0
	var a := _lp(150.0)
	for i in b.size():
		var t := float(i) / RATE
		lp += a * (_noise() - lp)
		var tone := sin(TAU * 41.0 * t) * 0.5 + sin(TAU * 55.5 * t) * 0.3 + sin(TAU * 82.0 * t) * 0.1
		b[i] = (tone + lp * 3.0) * (0.75 + 0.25 * sin(TAU * t / 6.0))
	return _to_wav(b, 0.6, true)


func _fire() -> AudioStreamWAV:
	var b := _buf(3.0)
	var lp := 0.0
	var a := _lp(700.0)
	var crackle := 0.0
	for i in b.size():
		lp += a * (_noise() - lp)
		if _rng.randf() < 0.0006:
			crackle = _rng.randf_range(0.4, 1.0)
		crackle *= 0.993
		b[i] = lp * 1.2 + _noise() * crackle
	return _to_wav(b, 0.6, true)
