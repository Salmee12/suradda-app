import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import '../core/network/dio_client.dart';
import '../presentation/viewmodels/hotspot_room_viewmodel.dart';
import '../services/audio/local_audio_service.dart';
import '../services/auth/token_storage_service.dart';
import '../services/audio/playback_service.dart';
import '../data/datasources/remote/auth_api.dart';
import '../data/datasources/remote/song_api.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/song_repository.dart';
import '../presentation/viewmodels/auth_viewmodel.dart';
import '../presentation/viewmodels/library_viewmodel.dart';

import '../data/datasources/remote/room_api.dart';
import '../data/repositories/room_repository.dart';
import '../services/streaming/local_stream_client_service.dart';
import '../services/streaming/local_stream_host_service.dart';
import '../services/streaming/online_room_socket_service.dart';
import '../presentation/viewmodels/online_room_viewmodel.dart';

final locator = GetIt.instance;

void setupLocator() {
  locator.registerLazySingleton<LocalAudioService>(() => LocalAudioService());
  locator.registerLazySingleton<TokenStorageService>(() => TokenStorageService());
  locator.registerLazySingleton<Dio>(() => DioClient(locator<TokenStorageService>()).dio);
  locator.registerLazySingleton<PlaybackService>(() => PlaybackService());

  locator.registerLazySingleton<AuthApi>(() => AuthApi(locator<Dio>()));
  locator.registerLazySingleton<AuthRepository>(
        () => AuthRepository(locator<AuthApi>(), locator<TokenStorageService>()),
  );
  locator.registerFactory<AuthViewModel>(() => AuthViewModel(locator<AuthRepository>()));

  locator.registerLazySingleton<SongApi>(() => SongApi(locator<Dio>()));
  locator.registerLazySingleton<SongRepository>(() => SongRepository(locator<SongApi>()));
  locator.registerFactory<LibraryViewModel>(
          () => LibraryViewModel(
        locator<SongRepository>(),
        locator<LocalAudioService>(),
        locator<PlaybackService>(),
      ),
  );
 // locator.registerFactory<LocalStreamHostService>(() => LocalStreamHostService());
  //locator.registerFactory<LocalStreamClientService>(() => LocalStreamClientService());
  locator.registerLazySingleton<RoomApi>(() => RoomApi(locator<Dio>()));
  locator.registerLazySingleton<RoomRepository>(() => RoomRepository(locator<RoomApi>()));
  // CHANGE: registerFactory -> registerLazySingleton
  locator.registerLazySingleton<OnlineRoomSocketService>(() => OnlineRoomSocketService());
  locator.registerLazySingleton<OnlineRoomViewModel>(
        () => OnlineRoomViewModel(
             locator<RoomRepository>(),
             locator<SongRepository>(),
             locator<OnlineRoomSocketService>(),
             locator<PlaybackService>(),
             locator<TokenStorageService>(),
    ),
  );
  // Add to your lib/di/locator.dart setup function:

  locator.registerLazySingleton<LocalStreamHostService>(() => LocalStreamHostService());
  locator.registerLazySingleton<LocalStreamClientService>(() => LocalStreamClientService());

  locator.registerLazySingleton<HotspotRoomViewModel>(
        () => HotspotRoomViewModel(
      hostService: locator<LocalStreamHostService>(),
      clientService: locator<LocalStreamClientService>(),
      playbackService: locator<PlaybackService>(),
    ),
  );
}







// inside setupLocator():

