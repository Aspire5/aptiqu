enum FeedbackCue {
  sessionStart('session_start_option_a.wav', 290),
  tick('timer_tick_normal_option_a.wav', 45),
  urgentTick('timer_tick_final10_option_a.wav', 55),
  correct('answer_correct_option_a.wav', 539),
  incorrect('answer_wrong_option_b.wav', 533),
  complete('session_complete_option_b.wav', 1002),
  victory('pvp_victory_option_a.wav', 3785),
  levelUp('level_up_option_a.wav', 1387);

  const FeedbackCue(this.filename, this.durationMs);
  final String filename;
  final int durationMs;
  String get asset => 'audio/feedback/$filename';
  bool get isTick => this == tick || this == urgentTick;
  double get volume => isTick ? (this == urgentTick ? .28 : .13) : .65;
}

enum TimerAudio { off, lastTen, full }
