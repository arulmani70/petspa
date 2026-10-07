import 'package:get_it/get_it.dart';
import 'package:shear_heaven_pet_spa/src/auth/repo/auth_repository.dart';
import 'package:shear_heaven_pet_spa/src/bookings/repo/booking_repository.dart';
import 'package:shear_heaven_pet_spa/src/bookings/services/booking_draft.dart';
import 'package:shear_heaven_pet_spa/src/chat/repo/chat_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/api_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/repos/database_repository.dart';
import 'package:shear_heaven_pet_spa/src/common/services/customer_socket_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/device_id_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/groomer_socket_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/network_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/session_service.dart';
import 'package:shear_heaven_pet_spa/src/common/services/push_notification_service.dart';
import 'package:shear_heaven_pet_spa/src/content/repo/content_repository.dart';
import 'package:shear_heaven_pet_spa/src/groomer/home/repo/groomer_home_repository.dart';
import 'package:shear_heaven_pet_spa/src/groomer/login/repo/groomer_login_repository.dart';
import 'package:shear_heaven_pet_spa/src/groomer/register/repo/groomer_register_repository.dart';
import 'package:shear_heaven_pet_spa/src/groomer/repo/groomer_repository.dart';
import 'package:shear_heaven_pet_spa/src/home/repo/gallery_repository.dart';
import 'package:shear_heaven_pet_spa/src/notifications/repo/notification_repository.dart';
import 'package:shear_heaven_pet_spa/src/offers/repo/offer_repository.dart';
import 'package:shear_heaven_pet_spa/src/pets/repo/pet_repository.dart';
import 'package:shear_heaven_pet_spa/src/services/repo/service_repository.dart';
import 'package:shear_heaven_pet_spa/src/store/repo/store_repository.dart';

final GetIt serviceLocator = GetIt.instance;

class ServicesLocator {
  static Future<void> initialize() async {
    serviceLocator.registerLazySingleton<DatabaseRepository>(() => DatabaseRepository());

    serviceLocator.registerLazySingleton<DeviceIdService>(() => DeviceIdService());

    serviceLocator.registerLazySingleton<ApiRepository>(() => ApiRepository());

    serviceLocator.registerLazySingleton<NetworkService>(() => NetworkService());

    serviceLocator.registerLazySingleton<SessionService>(() => SessionService());

    serviceLocator.registerLazySingleton<CustomerSocketService>(() => CustomerSocketService());

    serviceLocator.registerLazySingleton<GroomerSocketService>(() => GroomerSocketService());

    serviceLocator.registerLazySingleton<AuthRepository>(() => AuthRepository());

    serviceLocator.registerLazySingleton<GroomerLoginRepository>(() => GroomerLoginRepository());

    serviceLocator.registerLazySingleton<GroomerRegisterRepository>(() => GroomerRegisterRepository());

    serviceLocator.registerLazySingleton<GroomerHomeRepository>(() => GroomerHomeRepository());

    serviceLocator.registerLazySingleton<GroomerRepository>(() => GroomerRepository());

    serviceLocator.registerLazySingleton<PetRepository>(() => PetRepository());

    serviceLocator.registerLazySingleton<ServiceRepository>(() => ServiceRepository());

    serviceLocator.registerLazySingleton<BookingRepository>(() => BookingRepository());

    serviceLocator.registerLazySingleton<StoreRepository>(() => StoreRepository());

    serviceLocator.registerLazySingleton<NotificationRepository>(() => NotificationRepository());

    serviceLocator.registerLazySingleton<OfferRepository>(() => OfferRepository());

    serviceLocator.registerLazySingleton<ChatRepository>(() => ChatRepository());

    serviceLocator.registerLazySingleton<ContentRepository>(() => ContentRepository());

    serviceLocator.registerLazySingleton<GalleryRepository>(() => GalleryRepository());

    serviceLocator.registerLazySingleton<PushNotificationService>(() => PushNotificationService());

    serviceLocator.registerLazySingleton<BookingDraft>(() => BookingDraft());

    await serviceLocator<DeviceIdService>().initialize();
    await serviceLocator<ApiRepository>().initialize();
    await serviceLocator<NetworkService>().initialize();
    await serviceLocator<SessionService>().initialize();
    await serviceLocator<CustomerSocketService>().initialize();
    await serviceLocator<GroomerSocketService>().initialize();
    await serviceLocator<AuthRepository>().initialize();
    await serviceLocator<GroomerLoginRepository>().initialize();
    await serviceLocator<GroomerRegisterRepository>().initialize();
    await serviceLocator<GroomerHomeRepository>().initialize();
    await serviceLocator<GroomerRepository>().initialize();
    await serviceLocator<PetRepository>().initialize();
    await serviceLocator<ServiceRepository>().initialize();
    await serviceLocator<BookingRepository>().initialize();
    await serviceLocator<StoreRepository>().initialize();
    await serviceLocator<NotificationRepository>().initialize();
    await serviceLocator<OfferRepository>().initialize();
    await serviceLocator<ChatRepository>().initialize();
    await serviceLocator<ContentRepository>().initialize();
    await serviceLocator<GalleryRepository>().initialize();
    await serviceLocator<PushNotificationService>().initialize();
  }

  static DatabaseRepository get databaseRepository => serviceLocator<DatabaseRepository>();
  static DeviceIdService get deviceIdService => serviceLocator<DeviceIdService>();
  static ApiRepository get apiRepository => serviceLocator<ApiRepository>();
  static NetworkService get networkService => serviceLocator<NetworkService>();
  static SessionService get sessionService => serviceLocator<SessionService>();
  static PushNotificationService get pushNotificationService => serviceLocator<PushNotificationService>();
  static bool get isPushNotificationServiceRegistered => serviceLocator.isRegistered<PushNotificationService>();
  static CustomerSocketService get customerSocketService => serviceLocator<CustomerSocketService>();
  static bool get isCustomerSocketServiceRegistered => serviceLocator.isRegistered<CustomerSocketService>();
  static GroomerSocketService get groomerSocketService => serviceLocator<GroomerSocketService>();
  static bool get isGroomerSocketServiceRegistered => serviceLocator.isRegistered<GroomerSocketService>();
  static AuthRepository get authRepository => serviceLocator<AuthRepository>();
  static GroomerLoginRepository get groomerLoginRepository => serviceLocator<GroomerLoginRepository>();
  static GroomerRegisterRepository get groomerRegisterRepository => serviceLocator<GroomerRegisterRepository>();
  static GroomerHomeRepository get groomerHomeRepository => serviceLocator<GroomerHomeRepository>();
  static GroomerRepository get groomerRepository => serviceLocator<GroomerRepository>();
  static GroomerRepository get groomerAuthRepository => serviceLocator<GroomerRepository>();
  static PetRepository get petRepository => serviceLocator<PetRepository>();
  static ServiceRepository get serviceRepository => serviceLocator<ServiceRepository>();
  static BookingRepository get bookingRepository => serviceLocator<BookingRepository>();
  static StoreRepository get storeRepository => serviceLocator<StoreRepository>();
  static NotificationRepository get notificationRepository => serviceLocator<NotificationRepository>();
  static OfferRepository get offerRepository => serviceLocator<OfferRepository>();
  static ChatRepository get chatRepository => serviceLocator<ChatRepository>();
  static ContentRepository get contentRepository => serviceLocator<ContentRepository>();
  static GalleryRepository get galleryRepository => serviceLocator<GalleryRepository>();
  static BookingDraft get bookingDraft => serviceLocator<BookingDraft>();
}
