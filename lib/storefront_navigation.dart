/// Scroll to the top only when Home is tapped while Home is already active.
/// Switching back from Profile, Categories, Cart or Favorites preserves the
/// customer's catalogue position.
bool shouldScrollHomeToTop(int currentTab, int tappedTab) =>
    currentTab == 0 && tappedTab == 0;
