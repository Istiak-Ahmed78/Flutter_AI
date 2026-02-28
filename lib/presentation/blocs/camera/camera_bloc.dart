import 'dart:io';
import 'package:camera/camera.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'camera_event.dart';
part 'camera_state.dart';

class CameraBloc extends Bloc<CameraEvent, CameraState> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;

  CameraBloc() : super(CameraInitial()) {
    on<InitializeCameraEvent>(_onInitializeCamera);
    on<SwitchCameraEvent>(_onSwitchCamera);
    on<CapturePhotoEvent>(_onCapturePhoto);
    on<DisposeCameraEvent>(_onDisposeCamera);
  }

  CameraController? get controller => _controller;

  Future<void> _onInitializeCamera(
    InitializeCameraEvent event,
    Emitter<CameraState> emit,
  ) async {
    try {
      emit(CameraLoading());

      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        emit(const CameraError('No cameras found on this device'));
        return;
      }

      // Default to back camera
      _currentCameraIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_currentCameraIndex == -1) _currentCameraIndex = 0;

      await _initController(_cameras[_currentCameraIndex]);

      emit(CameraReady(controller: _controller!));
    } catch (e) {
      emit(CameraError(e.toString()));
    }
  }

  Future<void> _onSwitchCamera(
    SwitchCameraEvent event,
    Emitter<CameraState> emit,
  ) async {
    try {
      emit(CameraLoading());

      await _controller?.dispose();

      _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;

      await _initController(_cameras[_currentCameraIndex]);

      emit(CameraReady(controller: _controller!));
    } catch (e) {
      emit(CameraError(e.toString()));
    }
  }

  Future<void> _onCapturePhoto(
    CapturePhotoEvent event,
    Emitter<CameraState> emit,
  ) async {
    try {
      if (_controller == null || !_controller!.value.isInitialized) {
        emit(const CameraError('Camera not ready'));
        return;
      }

      final currentState = state;

      // Emit capturing state
      if (currentState is CameraReady) {
        emit(CameraCapturing(controller: _controller!));
      }

      final XFile file = await _controller!.takePicture();
      final imageFile = File(file.path);

      emit(CameraPhotoCaptured(controller: _controller!, imageFile: imageFile));
    } catch (e) {
      emit(CameraError(e.toString()));
    }
  }

  Future<void> _onDisposeCamera(
    DisposeCameraEvent event,
    Emitter<CameraState> emit,
  ) async {
    await _controller?.dispose();
    _controller = null;
    emit(CameraInitial());
  }

  Future<void> _initController(CameraDescription camera) async {
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _controller!.initialize();
  }

  @override
  Future<void> close() async {
    await _controller?.dispose();
    return super.close();
  }
}
