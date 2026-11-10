import 'package:flutter_test/flutter_test.dart';
import 'package:tool_lab/tools/x_feed/api/x_timeline_parser.dart';
import 'package:tool_lab/tools/x_feed/models/x_media.dart';

Map<String, Object?> _user(String id, String handle) => {
  'rest_id': id,
  'is_blue_verified': true,
  'core': {'name': 'Name $handle', 'screen_name': handle},
  'avatar': {
    'image_url': 'https://pbs.twimg.com/profile_images/1/a_normal.jpg',
  },
  'legacy': <String, Object?>{},
};

Map<String, Object?> _tweet(
  String id, {
  String text = 'hello',
  Map<String, Object?> legacy = const {},
  Map<String, Object?>? retweet,
}) => {
  '__typename': 'Tweet',
  'rest_id': id,
  'core': {
    'user_results': {'result': _user('u$id', 'user$id')},
  },
  'views': {'count': '1200'},
  'legacy': {
    'id_str': id,
    'full_text': text,
    'created_at': 'Wed Oct 10 20:19:24 +0000 2018',
    'favorite_count': 5,
    'retweet_count': 2,
    'reply_count': 1,
    'favorited': true,
    'entities': <String, Object?>{},
    if (retweet != null) 'retweeted_status_result': {'result': retweet},
    ...legacy,
  },
};

Map<String, Object?> _item(
  String entryId,
  Map<String, Object?> tweet, {
  bool promoted = false,
}) => {
  'entryId': entryId,
  'content': {
    'entryType': 'TimelineTimelineItem',
    'itemContent': {
      'itemType': 'TimelineTweet',
      'tweet_results': {'result': tweet},
      if (promoted) 'promotedMetadata': <String, Object?>{},
    },
  },
};

void main() {
  final json = {
    'data': {
      'home': {
        'home_timeline_urt': {
          'instructions': [
            {
              'type': 'TimelineAddEntries',
              'entries': [
                _item(
                  'tweet-1',
                  _tweet(
                    '1',
                    text: 'read https://t.co/abc now',
                    legacy: {
                      'entities': {
                        'urls': [
                          {
                            'url': 'https://t.co/abc',
                            'expanded_url': 'https://example.com/story',
                            'display_url': 'example.com/story',
                          },
                        ],
                      },
                    },
                  ),
                ),
                _item('promoted-tweet-2', _tweet('2')),
                _item('tweet-3', _tweet('3'), promoted: true),
                _item(
                  'tweet-4',
                  _tweet(
                    '4',
                    text: 'RT @user5: original',
                    retweet: _tweet(
                      '5',
                      text: 'clip https://t.co/media',
                      legacy: {
                        'display_text_range': [0, 4],
                        'extended_entities': {
                          'media': [
                            {
                              'type': 'video',
                              'media_url_https':
                                  'https://pbs.twimg.com/ext_tw_video_thumb/5/pu/img/x.jpg',
                              'original_info': {'width': 1280, 'height': 720},
                              'video_info': {
                                'duration_millis': 15000,
                                'variants': [
                                  {
                                    'content_type': 'application/x-mpegURL',
                                    'url': 'https://video.twimg.com/a.m3u8',
                                  },
                                  {
                                    'content_type': 'video/mp4',
                                    'bitrate': 832000,
                                    'url': 'https://video.twimg.com/low.mp4',
                                  },
                                  {
                                    'content_type': 'video/mp4',
                                    'bitrate': 2176000,
                                    'url': 'https://video.twimg.com/high.mp4',
                                  },
                                ],
                              },
                            },
                          ],
                        },
                      },
                    ),
                  ),
                ),
                {
                  'entryId': 'who-to-follow-6',
                  'content': {
                    'entryType': 'TimelineTimelineModule',
                    'items': [
                      {
                        'item': {
                          'itemContent': {
                            'itemType': 'TimelineTweet',
                            'tweet_results': {'result': _tweet('6')},
                          },
                        },
                      },
                    ],
                  },
                },
                {
                  'entryId': 'home-conversation-7',
                  'content': {
                    'entryType': 'TimelineTimelineModule',
                    'items': [
                      {
                        'item': {
                          'itemContent': {
                            'itemType': 'TimelineTweet',
                            'tweet_results': {
                              'result': {
                                '__typename': 'TweetWithVisibilityResults',
                                'tweet': _tweet('7'),
                              },
                            },
                          },
                        },
                      },
                    ],
                  },
                },
                {
                  'entryId': 'cursor-bottom-1',
                  'content': {
                    'entryType': 'TimelineTimelineCursor',
                    'cursorType': 'Bottom',
                    'value': 'NEXT',
                  },
                },
              ],
            },
          ],
        },
      },
    },
  };

  test('keeps posts, drops ads and recommendation modules', () {
    final page = XTimelineParser.parse(json);
    expect(page.posts.map((p) => p.id), ['1', '5', '7']);
    expect(page.bottomCursor, 'NEXT');
  });

  test('replaces t.co wrappers with the real link', () {
    final post = XTimelineParser.parse(json).posts.first;
    expect(post.text, 'read example.com/story now');
    expect(post.links.single.url, 'https://example.com/story');
    expect(post.engagement.liked, isTrue);
    expect(post.views, 1200);
    expect(post.createdAt, DateTime.utc(2018, 10, 10, 20, 19, 24));
  });

  test('unwraps reposts and picks the best mp4', () {
    final post = XTimelineParser.parse(json).posts[1];
    expect(post.repostedBy?.screenName, 'user4');
    expect(post.author.screenName, 'user5');
    expect(post.text, 'clip');
    final media = post.media.single;
    expect(media.type, XMediaType.video);
    expect(media.videoUrl, 'https://video.twimg.com/high.mp4');
    expect(media.durationMs, 15000);
    expect(post.url, 'https://x.com/user5/status/5');
  });

  test('builds pbs.twimg.com renditions', () {
    const media = XMedia(
      type: XMediaType.photo,
      imageUrl: 'https://pbs.twimg.com/media/abc.jpg',
      width: 10,
      height: 10,
    );
    expect(
      media.fullUrl,
      'https://pbs.twimg.com/media/abc?format=jpg&name=large',
    );
  });
}
