import 'package:equran/backend/base_db.dart';

class DuaFavouritesDB extends BaseDB {
  DuaFavouritesDB._privateConstructor() : super('dua_favourites');

  static final DuaFavouritesDB _instance =
      DuaFavouritesDB._privateConstructor();

  factory DuaFavouritesDB() {
    return _instance;
  }
}
