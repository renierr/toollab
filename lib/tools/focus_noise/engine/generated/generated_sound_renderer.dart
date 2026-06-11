typedef StereoSample = (double left, double right);

abstract class GeneratedSoundRenderer {
  void reset();

  StereoSample nextStereo();
}
