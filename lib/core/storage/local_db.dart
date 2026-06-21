import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/chat/domain/entities/message_entity.dart';
import '../../features/chat/domain/entities/chat_entity.dart';

class LocalDb {
  late final Isar isar;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open(
      [MessageEntitySchema, ChatEntitySchema],
      directory: dir.path,
    );
  }

  // --- Messages ---
  Future<void> saveMessage(MessageEntity message) async {
    await isar.writeTxn(() async {
      await isar.messageEntitys.put(message);
    });
  }

  Future<void> saveMessages(List<MessageEntity> messages) async {
    await isar.writeTxn(() async {
      await isar.messageEntitys.putAll(messages);
    });
  }

  Stream<List<MessageEntity>> watchMessagesForChat(String chatId) {
    return isar.messageEntitys
        .filter()
        .chatIdEqualTo(chatId)
        .sortByTimestamp()
        .watch(fireImmediately: true);
  }

  Future<MessageEntity?> getLastMessageForChat(String chatId) async {
    return await isar.messageEntitys
        .filter()
        .chatIdEqualTo(chatId)
        .sortByTimestampDesc()
        .findFirst();
  }

  /// Oldest locally-cached message for a chat — used as the cursor when
  /// backfilling older history from the server.
  Future<MessageEntity?> getOldestMessageForChat(String chatId) async {
    return await isar.messageEntitys
        .filter()
        .chatIdEqualTo(chatId)
        .sortByTimestamp()
        .findFirst();
  }

  Future<void> clearChat(String chatId) async {
    await isar.writeTxn(() async {
      await isar.messageEntitys.filter().chatIdEqualTo(chatId).deleteAll();
    });
  }

  Future<void> updateMessage(MessageEntity message) async {
    await isar.writeTxn(() async {
      await isar.messageEntitys.put(message);
    });
  }

  Future<void> deleteMessage(String messageId) async {
    await isar.writeTxn(() async {
      await isar.messageEntitys.filter().messageIdEqualTo(messageId).deleteAll();
    });
  }

  // --- Chats ---
  Future<void> saveChat(ChatEntity chat) async {
    await isar.writeTxn(() async {
      await isar.chatEntitys.put(chat);
    });
  }

  Stream<List<ChatEntity>> watchChats() {
    return isar.chatEntitys
        .where()
        .sortByTimeDesc()
        .watch(fireImmediately: true);
  }
}
