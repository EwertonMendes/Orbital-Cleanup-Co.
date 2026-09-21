extends RefCounted
class_name ProceduralSfx

const MIX_RATE := 22050

static func scanner_ping() -> AudioStreamWAV:
	return _make_tone(720.0, 1180.0, 0.16, 0.44, 0.10)

static func collect() -> AudioStreamWAV:
	return _make_tone(520.0, 860.0, 0.18, 0.52, 0.18)

static func discovery() -> AudioStreamWAV:
	return _make_chord(PackedFloat32Array([660.0, 880.0, 1320.0]), 0.46, 0.48)

static func unload() -> AudioStreamWAV:
	return _make_chord(PackedFloat32Array([360.0, 540.0, 720.0]), 0.28, 0.42)

static func perfect() -> AudioStreamWAV:
	return _make_chord(PackedFloat32Array([523.25, 659.25, 783.99, 1046.5]), 0.62, 0.46)

static func promotion() -> AudioStreamWAV:
	return _make_chord(PackedFloat32Array([440.0, 659.25, 880.0, 1318.5]), 0.78, 0.50)

static func impact() -> AudioStreamWAV:
	return _make_tone(160.0, 86.0, 0.12, 0.32, 0.48)

static func _make_tone(
	start_frequency: float,
	end_frequency: float,
	duration: float,
	volume: float,
	noise_amount: float
) -> AudioStreamWAV:
	var count := maxi(int(round(duration * MIX_RATE)), 64)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0

	for index in range(count):
		var t := float(index) / float(maxi(count - 1, 1))
		var frequency := lerpf(start_frequency, end_frequency, t)
		phase += TAU * frequency / float(MIX_RATE)
		var attack := smoothstep(0.0, 0.08, t)
		var release := 1.0 - smoothstep(0.62, 1.0, t)
		var envelope := attack * release
		var harmonic := sin(phase) * 0.78 + sin(phase * 2.01) * 0.22
		var deterministic_noise := sin(float(index) * 12.9898) * 43758.5453
		deterministic_noise = (deterministic_noise - floor(deterministic_noise)) * 2.0 - 1.0
		var sample := (harmonic * (1.0 - noise_amount) + deterministic_noise * noise_amount) * envelope * volume
		data.encode_s16(index * 2, int(round(clampf(sample, -1.0, 1.0) * 32767.0)))

	return _stream_from_data(data)

static func _make_chord(frequencies: PackedFloat32Array, duration: float, volume: float) -> AudioStreamWAV:
	var count := maxi(int(round(duration * MIX_RATE)), 64)
	var data := PackedByteArray()
	data.resize(count * 2)

	for index in range(count):
		var t := float(index) / float(maxi(count - 1, 1))
		var attack := smoothstep(0.0, 0.06, t)
		var release := 1.0 - smoothstep(0.56, 1.0, t)
		var envelope := attack * release
		var sample := 0.0
		for tone_index in range(frequencies.size()):
			var frequency := frequencies[tone_index]
			var phase := TAU * frequency * float(index) / float(MIX_RATE)
			sample += sin(phase + float(tone_index) * 0.17)
		sample /= maxf(float(frequencies.size()), 1.0)
		sample *= envelope * volume
		data.encode_s16(index * 2, int(round(clampf(sample, -1.0, 1.0) * 32767.0)))

	return _stream_from_data(data)

static func _stream_from_data(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
