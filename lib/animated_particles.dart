/// Public entry point for the animated_particles package.
/// Re-exports everything needed to use a [ParticleField].
library;

export 'src/config/enums.dart';
export 'src/config/particle_field_config.dart';
export 'src/particle_field_controller.dart';
export 'src/particle_field_widget.dart';
export 'src/targets/particle_target.dart' show ParticleTarget, PointSampler;
export 'src/targets/pixel_sampler.dart' show SampleMode, SampledTemplate;
