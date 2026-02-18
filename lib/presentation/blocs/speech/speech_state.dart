part of 'speech_bloc.dart';

abstract class SpeechState extends Equatable {
  const SpeechState();

  @override
  List<Object> get props => [];
}

class SpeechInitial extends SpeechState {}

class SpeechListening extends SpeechState {
  final String transcript;

  const SpeechListening({this.transcript = ''});

  @override
  List<Object> get props => [transcript];
}

class SpeechProcessing extends SpeechState {
  final String recognizedText;

  const SpeechProcessing(this.recognizedText);

  @override
  List<Object> get props => [recognizedText];
}

class SpeechResult extends SpeechState {
  final String text;

  const SpeechResult(this.text);

  @override
  List<Object> get props => [text];
}

class Speaking extends SpeechState {
  final String text;

  const Speaking(this.text);

  @override
  List<Object> get props => [text];
}

class SpeechError extends SpeechState {
  final String message;

  const SpeechError(this.message);

  @override
  List<Object> get props => [message];
}

class SpeechIdle extends SpeechState {}
