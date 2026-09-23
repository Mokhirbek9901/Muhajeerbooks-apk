self.addEventListener('push', (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (_) {
    data = { body: event.data ? event.data.text() : '' };
  }

  const title = data.title || 'Muhajeer Books';
  const options = {
    body: data.body || '',
    icon: data.icon || '/icons/Icon-192.png',
    badge: data.badge || '/icons/Icon-192.png',
    data: { url: data.url || '/', messageId: data.message_id || '', openInbox: data.open_inbox === true },
    tag: data.tag || 'muhajeer-books',
    renotify: true
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const openInbox = event.notification.data?.openInbox === true;
  const rawTarget = openInbox ? '/?open=notifications' : (event.notification.data?.url || '/');
  const target = new URL(rawTarget, self.location.origin).href;
  event.waitUntil((async () => {
    try {
      const messageId = event.notification.data?.messageId || '';
      const subscription = await self.registration.pushManager.getSubscription();
      if (messageId && subscription?.endpoint) {
        const key = 'sb_publishable_5lDr_sw4bu8g3x8LCVzp4g_sHSTMBiO';
        await fetch('/supabase/functions/v1/customer-rpc', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'apikey': key,
            'Authorization': 'Bearer ' + key
          },
          body: JSON.stringify({
            name: 'customer_push_open',
            params: {
              p_message_id: messageId,
              p_endpoint: subscription.endpoint
            }
          })
        });
      }
    } catch (_) {}

    const clientsList = await clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const client of clientsList) {
      if (client.url.startsWith(self.location.origin) && 'focus' in client) {
        await client.focus();
        if ('navigate' in client) await client.navigate(target);
        return;
      }
    }
    if (clients.openWindow) await clients.openWindow(target);
  })());
});
