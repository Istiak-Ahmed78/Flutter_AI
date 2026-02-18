part of 'speech_bloc.dart'; // This should point to speech_bloc.dart, not itself

abstract class SpeechEvent extends Equatable {
  const SpeechEvent();

  @override
  List<Object> get props => [];
}

class StartListeningEvent extends SpeechEvent {}

class StopListeningEvent extends SpeechEvent {}

class SpeechResultEvent extends SpeechEvent {
  final String text;

  const SpeechResultEvent(this.text);

  @override
  List<Object> get props => [text];
}

class SpeakTextEvent extends SpeechEvent {
  final String text;

  const SpeakTextEvent(this.text);

  @override
  List<Object> get props => [text];
}

class StopSpeakingEvent extends SpeechEvent {}

class ListeningStateChangedEvent extends SpeechEvent {
  final bool isListening;

  const ListeningStateChangedEvent(this.isListening);

  @override
  List<Object> get props => [isListening];
}
