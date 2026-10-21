#pragma once

#include <algorithm>
#include <utility>

namespace aurora::gfx::detail {
// Called with the pipeline mutex held; pending values track background queue membership.
template <typename Key, typename Queue, typename Pending>
void promote_pending_pipeline(Key hash, bool blocking, Queue& background, Queue& priority, Pending& pending) {
  const auto pendingIt = pending.find(hash);
  if (pendingIt == pending.end() || !pendingIt->second) {
    return;
  }
  auto backgroundIt = std::find_if(background.begin(), background.end(),
                                   [=](const auto& entry) { return entry.hash == hash; });
  if (backgroundIt == background.end()) {
    return;
  }
  if (blocking) {
    priority.emplace_front(std::move(*backgroundIt));
  } else {
    priority.emplace_back(std::move(*backgroundIt));
  }
  background.erase(backgroundIt);
  pendingIt->second = false;
}
} // namespace aurora::gfx::detail
