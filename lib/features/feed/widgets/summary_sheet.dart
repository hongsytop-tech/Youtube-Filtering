import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_service.dart';
import '../providers/summary_providers.dart';

/// Bottom sheet that shows an AI summary of a video, generating it on first
/// open (button-triggered only) and caching the result.
class SummarySheet extends ConsumerStatefulWidget {
  const SummarySheet({super.key, required this.videoId, required this.title});

  final String videoId;
  final String title;

  @override
  ConsumerState<SummarySheet> createState() => _SummarySheetState();
}

class _SummarySheetState extends ConsumerState<SummarySheet> {
  String? _summary;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final cached = ref.read(summaryCacheProvider)[widget.videoId];
    if (cached != null) {
      _summary = cached;
    } else {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
    }
  }

  Future<void> _generate() async {
    if (!SupabaseService.isSignedIn) {
      setState(() => _error = '요약을 쓰려면 먼저 마이 탭에서 로그인/YouTube 연결을 해주세요.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await SupabaseService.client.functions.invoke(
        'summarize-video',
        body: {'videoId': widget.videoId},
      );
      final data = res.data as Map?;
      final summary = data?['summary'] as String?;
      if (summary != null && summary.isNotEmpty) {
        ref.read(summaryCacheProvider.notifier).put(widget.videoId, summary);
        setState(() => _summary = summary);
      } else {
        setState(() => _error =
            (data?['detail'] as String?) ?? '요약할 내용을 찾지 못했습니다. (자막·설명 부족)');
      }
    } catch (e) {
      setState(() => _error = '요약 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('AI 요약',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Text(
            widget.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('요약 생성 중…'),
                          ],
                        ),
                      ),
                    )
                  : _error != null
                      ? Text(_error!,
                          style: TextStyle(
                              color:
                                  Theme.of(context).colorScheme.error))
                      : SelectableText(_summary ?? ''),
            ),
          ),
          if (_error != null && !_loading)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
              ),
            ),
        ],
      ),
    );
  }
}
