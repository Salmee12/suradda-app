import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import '../core/network/auth_event_bus.dart';
import '../core/network/dio_client.dart';
import '../data/datasources/remote/bdapps_api.dart';
import '../presentation/viewmodels/hotspot_room_viewmodel.dart';
import '../services/audio/local_audio_service.dart';
import '../services/auth/token_storage_service.dart';
import '../services/audio/playback_service.dart';
import '../services/download/song_download_service.dart';
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
import '../services/streaming/radio_service.dart';
import '../presentation/viewmodels/online_room_viewmodel.dart';
import '../presentation/viewmodels/radio_viewmodel.dart';

final locator = GetIt.instance;

void setupLocator() {
  locator.registerLazySingleton<LocalAudioService>(() => LocalAudioService());
  locator.registerLazySingleton<TokenStorageService>(() => TokenStorageService());
  // Registered before Dio: the interceptor is built inside DioClient and needs
  // somewhere to announce 401/403 without holding a view model.
  locator.registerLazySingleton<AuthEventBus>(() => AuthEventBus());
  locator.registerLazySingleton<Dio>(
        () => DioClient(locator<TokenStorageService>(), locator<AuthEventBus>()).dio,
  );
  locator.registerLazySingleton<PlaybackService>(() => PlaybackService());

  locator.registerLazySingleton<AuthApi>(() => AuthApi(locator<Dio>()));
  // Deliberately not given locator<Dio>(): the PHP tier has its own base URL,
  // much longer timeouts and no bearer token, so it must not share the
  // interceptor-wrapped client.
  locator.registerLazySingleton<BdappsApi>(() => BdappsApi());
  locator.registerLazySingleton<AuthRepository>(
        () => AuthRepository(
      locator<AuthApi>(),
      locator<BdappsApi>(),
      locator<TokenStorageService>(),
    ),
  );
  // A singleton, not a factory: the OTP flow has to hold referenceNo across the
  // phone screen and the OTP screen, which a fresh instance per resolution
  // would throw away.
  locator.registerLazySingleton<AuthViewModel>(
        () => AuthViewModel(locator<AuthRepository>(), locator<AuthEventBus>()),
  );

  locator.registerLazySingleton<SongApi>(() => SongApi(locator<Dio>()));
  locator.registerLazySingleton<SongRepository>(() => SongRepository(locator<SongApi>()));
  locator.registerLazySingleton<SongDownloadService>(() => SongDownloadService());
  locator.registerFactory<LibraryViewModel>(
          () => LibraryViewModel(
        locator<SongRepository>(),
        locator<LocalAudioService>(),
        locator<PlaybackService>(),
        locator<SongDownloadService>(),
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
      tokenStorage: locator<TokenStorageService>(),
    ),
  );

  locator.registerLazySingleton<RadioService>(() => RadioService());
  // A singleton, not a factory: the radio keeps playing after you leave the
  // Radio tab, so the VM must survive the page being disposed. Lazy means the
  // station list isn't fetched until the tab is opened for the first time.
  locator.registerLazySingleton<RadioViewModel>(
        () => RadioViewModel(
      locator<RadioService>(),
      locator<PlaybackService>(),
    ),
  );
}







// inside setupLocator():

