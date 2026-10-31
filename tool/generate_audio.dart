// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void main() {
  final dir = Directory('assets/audio');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  File('assets/audio/tap.wav').writeAsBytesSync(generateTapWav());
  File('assets/audio/call.wav').writeAsBytesSync(generateCallWav());
  File('assets/audio/line.wav').writeAsBytesSync(generateLineWav());
  File('assets/audio/bingo.wav').writeAsBytesSync(generateBingoWav());

  print('Generated 4 audio WAV files in assets/audio/');
}

List<int> createWavHeader(int numSamples, int sampleRate) {
  final byteRate = sampleRate * 2;
  final dataSize = numSamples * 2;
  final fileSize = 36 + dataSize;

  final b = ByteData(44);
  // RIFF
  b.setUint8(0, 0x52);
  b.setUint8(1, 0x49);
  b.setUint8(2, 0x46);
  b.setUint8(3, 0x46);
  b.setUint32(4, fileSize, Endian.little);
  // WAVE
  b.setUint8(8, 0x57);
  b.setUint8(9, 0x41);
  b.setUint8(10, 0x56);
  b.setUint8(11, 0x45);
  // fmt
  b.setUint8(12, 0x66);
  b.setUint8(13, 0x6D);
  b.setUint8(14, 0x74);
  b.setUint8(15, 0x20);
  b.setUint32(16, 16, Endian.little); // chunk size
  b.setUint16(20, 1, Endian.little); // PCM format
  b.setUint16(22, 1, Endian.little); // mono
  b.setUint32(24, sampleRate, Endian.little);
  b.setUint32(28, byteRate, Endian.little);
  b.setUint16(32, 2, Endian.little); // block align
  b.setUint16(34, 16, Endian.little); // 16-bit
  // data
  b.setUint8(36, 0x64);
  b.setUint8(37, 0x61);
  b.setUint8(38, 0x74);
  b.setUint8(39, 0x61);
  b.setUint32(40, dataSize, Endian.little);

  return b.buffer.asUint8List();
}

Uint8List generateTapWav() {
  const sampleRate = 44100;
  const durationSec = 0.06;
  final numSamples = (sampleRate * durationSec).toInt();
  final header = createWavHeader(numSamples, sampleRate);

  final pcm = ByteData(numSamples * 2);
  for (int i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    final decay = exp(-t * 80);
    final freq = 800.0 - (t * 5000);
    final sample = (sin(2 * pi * max(100.0, freq) * t) * decay * 20000)
        .toInt()
        .clamp(-32768, 32767);
    pcm.setInt16(i * 2, sample, Endian.little);
  }

  return Uint8List.fromList([...header, ...pcm.buffer.asUint8List()]);
}

Uint8List generateCallWav() {
  const sampleRate = 44100;
  const durationSec = 0.18;
  final numSamples = (sampleRate * durationSec).toInt();
  final header = createWavHeader(numSamples, sampleRate);

  final pcm = ByteData(numSamples * 2);
  for (int i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    final decay = exp(-t * 18);
    // 880Hz (A5) with bell harmonic at 1760Hz
    final sample =
        ((sin(2 * pi * 880 * t) * 0.7 + sin(2 * pi * 1760 * t) * 0.3) *
                decay *
                24000)
            .toInt()
            .clamp(-32768, 32767);
    pcm.setInt16(i * 2, sample, Endian.little);
  }

  return Uint8List.fromList([...header, ...pcm.buffer.asUint8List()]);
}

Uint8List generateLineWav() {
  const sampleRate = 44100;
  const durationSec = 0.35;
  final numSamples = (sampleRate * durationSec).toInt();
  final header = createWavHeader(numSamples, sampleRate);

  final pcm = ByteData(numSamples * 2);
  for (int i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    final decay = exp(-t * 9);
    // Harmonious major third chord (C5 523Hz + E5 659Hz + G5 784Hz)
    final chord =
        (sin(2 * pi * 523.25 * t) * 0.4 +
        sin(2 * pi * 659.25 * t) * 0.35 +
        sin(2 * pi * 783.99 * t) * 0.25);
    final sample = (chord * decay * 25000).toInt().clamp(-32768, 32767);
    pcm.setInt16(i * 2, sample, Endian.little);
  }

  return Uint8List.fromList([...header, ...pcm.buffer.asUint8List()]);
}

Uint8List generateBingoWav() {
  const sampleRate = 44100;
  const durationSec = 0.7;
  final numSamples = (sampleRate * durationSec).toInt();
  final header = createWavHeader(numSamples, sampleRate);

  final pcm = ByteData(numSamples * 2);
  // Fanfare arpeggio: C5 (0..0.12s), E5 (0.12..0.24s), G5 (0.24..0.36s), C6 (0.36..0.7s)
  for (int i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    double freq;
    double noteStartTime;
    if (t < 0.12) {
      freq = 523.25;
      noteStartTime = 0.0;
    } else if (t < 0.24) {
      freq = 659.25;
      noteStartTime = 0.12;
    } else if (t < 0.36) {
      freq = 783.99;
      noteStartTime = 0.24;
    } else {
      freq = 1046.50; // C6 peak
      noteStartTime = 0.36;
    }
    final noteT = t - noteStartTime;
    final decay = exp(-noteT * (t < 0.36 ? 8 : 4));
    final sample = (sin(2 * pi * freq * t) * decay * 26000).toInt().clamp(
      -32768,
      32767,
    );
    pcm.setInt16(i * 2, sample, Endian.little);
  }

  return Uint8List.fromList([...header, ...pcm.buffer.asUint8List()]);
}
