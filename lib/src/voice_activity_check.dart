import 'dart:typed_data';
import 'dart:math';

bool checkVoiceActivity(Uint8List audioData, int sampleRate, {double threshold = 0.01}) {
  // Convert byte data to 16-bit PCM samples
  List<int> samples = [];
  for (int i = 0; i < audioData.length; i += 2) {
    int sample = audioData[i] | (audioData[i + 1] << 8);
    if (sample > 32767) sample -= 65536;
    samples.add(sample);
  }

  // Calculate RMS energy
  double sumOfSquares = 0;
  for (int sample in samples) {
    sumOfSquares += sample * sample;
  }
  double rms = sqrt(sumOfSquares / samples.length);

  // Normalize RMS to 0-1 range
  double normalizedRms = rms / 32768;

  // Check if normalized RMS is above the threshold
  return normalizedRms > threshold;
}
