import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChannelsScreen extends ConsumerWidget {
  const ChannelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('채널')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'YouTube 연결 후 구독 채널별로\n음소거·즐겨찾기·카테고리 지정을 할 수 있습니다.\n(다음 단계에서 구현)',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
