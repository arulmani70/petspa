// ignore_for_file: constant_identifier_names, non_constant_identifier_names

class DatabaseConstants {
  const DatabaseConstants();

  final String DB_NAME = "shear_heaven.db";
  final int DB_VERSION = 1;

  // Table names
  final String TABLE_USERS = "users";
  final String TABLE_PETS = "pets";
  final String TABLE_SERVICES = "services";
  final String TABLE_PACKAGES = "packages";
  final String TABLE_BOOKINGS = "bookings";

  // Shared columns
  final String COLUMN_ID = "id";
  final String COLUMN_REMOTE_ID = "remote_id";
  final String COLUMN_CREATED_AT = "created_at";
  final String COLUMN_UPDATED_AT = "updated_at";
  final String COLUMN_IS_DELETED = "is_deleted";
  final String COLUMN_SYNC_STATUS = "sync_status";
  final String COLUMN_LOCAL_VERSION = "local_version";
  final String COLUMN_SERVER_UPDATED_AT = "server_updated_at";

  // Sync statuses
  final String SYNC_STATUS_PENDING = "pending";
  final String SYNC_STATUS_SYNCED = "synced";
  final String SYNC_STATUS_CONFLICT = "conflict";

  // User columns
  final String COLUMN_NAME = "name";
  final String COLUMN_EMAIL = "email";
  final String COLUMN_PHONE = "phone";
  final String COLUMN_PASSWORD = "password";
  final String COLUMN_AVATAR_URL = "avatar_url";
  final String COLUMN_BIO = "bio";

  // Pet columns
  final String COLUMN_USER_ID = "user_id";
  final String COLUMN_PET_NAME = "pet_name";
  final String COLUMN_BREED = "breed";
  final String COLUMN_BIRTH_DATE = "birth_date";
  final String COLUMN_WEIGHT = "weight";
  final String COLUMN_COAT_TYPE = "coat_type";
  final String COLUMN_NOTES = "notes";
  final String COLUMN_PHOTO_URL = "photo_url";

  // Service columns
  final String COLUMN_SERVICE_ID = "service_id";
  final String COLUMN_SERVICE_NAME = "service_name";
  final String COLUMN_DESCRIPTION = "description";
  final String COLUMN_DURATION_MIN = "duration_min";
  final String COLUMN_PRICE = "price";
  final String COLUMN_CURRENCY = "currency";
  final String COLUMN_RATING = "rating";
  final String COLUMN_TAG = "tag";
  final String COLUMN_IMAGE_URL = "image_url";

  // Package columns
  final String COLUMN_PACKAGE_ID = "package_id";
  final String COLUMN_PACKAGE_NAME = "package_name";
  final String COLUMN_SESSIONS = "sessions";
  final String COLUMN_VALID_DAYS = "valid_days";
  final String COLUMN_INCLUDED_SERVICES = "included_services";

  // Booking columns
  final String COLUMN_BOOKING_ID = "booking_id";
  final String COLUMN_PET_ID = "pet_id";
  final String COLUMN_START_TIME = "start_time";
  final String COLUMN_END_TIME = "end_time";
  final String COLUMN_STATUS = "status";
  final String COLUMN_TOTAL_PRICE = "total_price";
  final String COLUMN_SLOT = "slot";
}
