"""Bounded notification history; only application-provided metadata identifies chats."""
import html
import math
import re
import uuid

DEFAULT_POLICY = {'days': 7, 'limit': 200}
MAX_HISTORY = 500
MAX_SOURCES = 128


def plain_text(value, limit):
    # App names, conversation names and summaries are plain text in the protocol.
    return str(value or '')[:limit]


BODY_TAGS = re.compile(r'</?(?:b|i|u)\s*>|</?a(?:\s+[^<>]*)?>|<img(?:\s+[^<>]*)?/?>', re.IGNORECASE)


def body_text(value, limit):
    # Remove only notification markup, not C++ templates or literal <tokens>.
    # Decode afterwards so escaped markup stays literal, and always render plain.
    return html.unescape(BODY_TAGS.sub('', str(value or '')))[:limit]


def policy(value):
    if not isinstance(value, dict):
        raise ValueError('invalid_notification_policy')
    days, limit = value.get('days'), value.get('limit')
    if type(days) is not int or days not in (1, 3, 7, 30):
        raise ValueError('invalid_notification_policy')
    if type(limit) is not int or limit not in (20, 50, 100, 200):
        raise ValueError('invalid_notification_policy')
    return {'days': days, 'limit': limit}


def normalize_policies(value):
    result = {}
    if isinstance(value, dict):
        for app, settings in list(value.items())[-MAX_SOURCES:]:
            try:
                if isinstance(app, str) and app:
                    result[app[:160]] = policy(settings)
            except ValueError:
                pass
    return result


def is_spotify(item):
    return item.get('desktopEntry', '').casefold().removesuffix('.desktop') in ('spotify', 'com.spotify.client') or item['app'].casefold() == 'spotify'


def notification(value, now):
    return {'id': uuid.uuid4().hex,
            'sourceId': int(value.get('sourceId', value.get('id', 0))),
            'session': str(value.get('session', ''))[:160],
            'actionToken': str(value.get('actionToken', ''))[:160],
            'app': plain_text(value.get('app') or 'Application', 160),
            'desktopEntry': str(value.get('desktopEntry', ''))[:200],
            'conversation': plain_text(value.get('conversation', ''), 200),
            'conversationId': str(value.get('conversationId', ''))[:200],
            'summary': plain_text(value.get('summary'), 512),
            'body': body_text(value.get('body'), 4096),
            'time': now, 'read': False}


def prune(items, policies, now):
    counts = {}
    result = []
    for item in reversed(items):
        settings = policies.get(item['app'], DEFAULT_POLICY)
        timestamp = item.get('time', 0)
        if not isinstance(timestamp, (int, float)) or not math.isfinite(timestamp) or timestamp < now - settings['days'] * 86400:
            continue
        key = ('spotify', item['app']) if is_spotify(item) else ('app', item['app'])
        limit = 1 if is_spotify(item) else settings['limit']
        if counts.get(key, 0) >= limit:
            continue
        counts[key] = counts.get(key, 0) + 1
        result.append(item)
        if len(result) >= MAX_HISTORY:
            break
    return list(reversed(result))


def append(items, value, policies, now):
    item = notification(value, now)
    retained = [n for n in items if (n['session'], n['sourceId']) != (item['session'], item['sourceId'])]
    return prune(retained + [item], policies, now), item
