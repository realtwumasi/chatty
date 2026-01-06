import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import '../../model/data_models.dart';
import '../../model/responsive_helper.dart';
import 'message_tile.dart';
import 'available_group_tile.dart';
import '../../services/chat_repository.dart';

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
      filteredChats = chats.where((c) => c.name.toLowerCase().contains(searchQuery.toLowerCase())).toList();
    }

    final joinedGroups = filteredChats.where((c) => c.isGroup && c.isMember).toList();
    final availableGroups = filteredChats.where((c) => c.isGroup && !c.isMember).toList();
    final privateChats = filteredChats.where((c) => !c.isGroup).toList();

    List<dynamic> listItems = []; // Can be Chat or String (header) or Widget (Divider)

    if (selectedFilterIndex == 0) { // All
      listItems.addAll(privateChats);
      listItems.addAll(joinedGroups);

      if (availableGroups.isNotEmpty) {
        listItems.add("available_groups_header");
        listItems.addAll(availableGroups);
      }
    } else if (selectedFilterIndex == 1) { // Private
      listItems.addAll(privateChats);
    } else if (selectedFilterIndex == 2) { // Groups
      listItems.addAll(joinedGroups);
      if (availableGroups.isNotEmpty) {
        listItems.add("available_groups_header");
        listItems.addAll(availableGroups);
      }
    }

    if (listItems.isEmpty) {
      if (isLoading && chats.isEmpty) return const Center(child: CircularProgressIndicator());
      return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[300]),
              SizedBox(height: 16),
              Text(
                "No chats found",
                style: TextStyle(color: Colors.grey[400], fontSize: Responsive.fontSize(context, 16)),
              ),
            ],
          )
      );
    }

    return RawKeyboardListener(
      focusNode: listFocusNode,
      onKey: (event) {
         // Basic arrow key navigation support could be re-implemented here if needed,
         // but simplifying for now as ListView handles focus well usually.
         // If we need custom selection movement, we need to pass that logic down or handle it in parent.
         // For now, let's keep it simple.
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
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                child: Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[400])),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      child: Text("Available groups to join", style: TextStyle(color: Colors.grey, fontSize: Responsive.fontSize(context, 12), fontWeight: FontWeight.bold)),
                    ),
                    Expanded(child: Divider(color: Colors.grey[400])),
                  ],
                ),
              );
            }

            if (item is Chat) {
              if (item.isGroup && !item.isMember) {
                return AvailableGroupTile(chat: item);
              } else {
                return MessageTile(
                  chat: item,
                  isSelected: selectedChat?.id == item.id,
                  onTap: () => onChatSelected(item),
                );
              }
            }

            return const SizedBox.shrink(); // Fallback
          },
        ),
      ),
    );
  }
}
