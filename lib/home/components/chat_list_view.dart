import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import '../../model/data_models.dart';
import '../../model/responsive_helper.dart';
import 'message_tile.dart';
import 'available_group_tile.dart';

class ChatListView extends ConsumerWidget {
  final List<Chat> chats;
  final bool isLoading;
  final String searchQuery;
  final int selectedFilterIndex;
  final Chat? selectedChat;
  final ValueChanged<Chat> onChatSelected;
  final ScrollController scrollController;
  final FocusNode listFocusNode;
  final bool isDesktop;

  const ChatListView({
    super.key,
    required this.chats,
    required this.isLoading,
    required this.searchQuery,
    required this.selectedFilterIndex,
    required this.selectedChat,
    required this.onChatSelected,
    required this.scrollController,
    required this.listFocusNode,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var filteredChats = chats;
    if (searchQuery.isNotEmpty) {
      filteredChats = chats
          .where(
            (c) => c.name.toLowerCase().contains(searchQuery.toLowerCase()),
          )
          .toList();
    }

    final joinedGroups = filteredChats
        .where((c) => c.isGroup && c.isMember)
        .toList();
    final availableGroups = filteredChats
        .where((c) => c.isGroup && !c.isMember)
        .toList();
    final privateChats = filteredChats.where((c) => !c.isGroup).toList();

    List<dynamic> listItems =
        []; // Can be Chat or String (header) or Widget (Divider)

    if (selectedFilterIndex == 0) {
      // All
      listItems.addAll(privateChats);
      listItems.addAll(joinedGroups);

      if (availableGroups.isNotEmpty) {
        listItems.add("available_groups_header");
        listItems.addAll(availableGroups);
      }
    } else if (selectedFilterIndex == 1) {
      // Private
      listItems.addAll(privateChats);
    } else if (selectedFilterIndex == 2) {
      // Groups
      listItems.addAll(joinedGroups);
      if (availableGroups.isNotEmpty) {
        listItems.add("available_groups_header");
        listItems.addAll(availableGroups);
      }
    }

    if (listItems.isEmpty) {
      if (isLoading && chats.isEmpty)
        return const Center(child: CircularProgressIndicator());
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text(
              "No chats found",
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: Responsive.fontSize(context, 16),
              ),
            ),
          ],
        ),
      );
    }

    return RawKeyboardListener(
      focusNode: listFocusNode,
      onKey: (event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _selectNextChat(listItems);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _selectPreviousChat(listItems);
          }
        }
      },
      child: Scrollbar(
        controller: scrollController,
        thumbVisibility: isDesktop,
        child: ListView.builder(
          controller: scrollController,
          itemCount: listItems.length,
          itemBuilder: (context, index) {
            final item = listItems[index];

            if (item == "available_groups_header") {
              return RepaintBoundary(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey[400])),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.w),
                        child: Text(
                          "Available groups to join",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: Responsive.fontSize(context, 12),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey[400])),
                    ],
                  ),
                ),
              );
            }

            if (item is Chat) {
              if (item.isGroup && !item.isMember) {
                return RepaintBoundary(child: AvailableGroupTile(chat: item));
              } else {
                return RepaintBoundary(
                  child: MessageTile(
                    chat: item,
                    isSelected: selectedChat?.id == item.id,
                    onTap: () => onChatSelected(item),
                  ),
                );
              }
            }

            return const SizedBox.shrink(); // Fallback
          },
        ),
      ),
    );
  }

  void _selectNextChat(List<dynamic> items) {
    if (items.isEmpty) return;
    final chatItems = items.whereType<Chat>().toList();
    if (chatItems.isEmpty) return;

    if (selectedChat == null) {
      onChatSelected(chatItems.first);
      return;
    }

    final currentIndex = chatItems.indexWhere((c) => c.id == selectedChat!.id);
    if (currentIndex != -1 && currentIndex < chatItems.length - 1) {
      onChatSelected(chatItems[currentIndex + 1]);
      _scrollToIndex(items.indexOf(chatItems[currentIndex + 1]));
    }
  }

  void _selectPreviousChat(List<dynamic> items) {
    if (items.isEmpty) return;
    final chatItems = items.whereType<Chat>().toList();
    if (chatItems.isEmpty) return;

    if (selectedChat == null) {
      onChatSelected(chatItems.last);
      return;
    }

    final currentIndex = chatItems.indexWhere((c) => c.id == selectedChat!.id);
    if (currentIndex > 0) {
      onChatSelected(chatItems[currentIndex - 1]);
      _scrollToIndex(items.indexOf(chatItems[currentIndex - 1]));
    }
  }

  void _scrollToIndex(int index) {
    if (!scrollController.hasClients) return;
    // Simple estimation: 72 is approx height of a tile
    final offset = index * 72.0;
    // Ideally we'd use scroll_to_index package, but simple autoscroll is fine for now
    if (offset < scrollController.offset ||
        offset >
            scrollController.offset +
                scrollController.position.viewportDimension) {
      scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }
}
