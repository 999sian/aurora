#include "gfx/pipeline_queue.hpp"

#include <gtest/gtest.h>
#include <deque>
#include <unordered_map>

namespace {
struct Pending {
  struct Key {
    unsigned value;
    unsigned* comparisons;
    bool operator==(unsigned other) const {
      ++*comparisons;
      return value == other;
    }
  } hash;
};

TEST(PipelineQueue, RepeatedPromotionDoesNotSearchBackgroundAgain) {
  unsigned comparisons = 0;
  std::deque<Pending> background{{{1, &comparisons}}, {{2, &comparisons}}, {{3, &comparisons}}};
  std::deque<Pending> priority;
  std::unordered_map<unsigned, bool> pending{{1, true}, {2, true}, {3, true}};
  aurora::gfx::detail::promote_pending_pipeline(2u, false, background, priority, pending);
  ASSERT_EQ(background.size(), 2u);
  ASSERT_EQ(priority.size(), 1u);
  EXPECT_EQ(priority.front().hash.value, 2u);
  EXPECT_FALSE(pending.at(2));

  comparisons = 0;
  aurora::gfx::detail::promote_pending_pipeline(2u, false, background, priority, pending);
  EXPECT_EQ(comparisons, 0u);
  EXPECT_EQ(priority.size(), 1u);
}

TEST(PipelineQueue, DequeuedOrUnknownPipelineDoesNotSearchBackground) {
  unsigned comparisons = 0;
  std::deque<Pending> background{{{1, &comparisons}}};
  std::deque<Pending> priority;
  std::unordered_map<unsigned, bool> pending{{1, true}, {2, false}};
  aurora::gfx::detail::promote_pending_pipeline(2u, true, background, priority, pending);
  aurora::gfx::detail::promote_pending_pipeline(3u, false, background, priority, pending);
  EXPECT_EQ(comparisons, 0u);
  EXPECT_TRUE(priority.empty());
}

TEST(PipelineQueue, BlockingPromotionPrecedesNormalAndPreservesBackgroundOrder) {
  unsigned comparisons = 0;
  std::deque<Pending> background{{{1, &comparisons}}, {{2, &comparisons}}, {{3, &comparisons}}};
  std::deque<Pending> priority{{{4, &comparisons}}};
  std::unordered_map<unsigned, bool> pending{{1, true}, {2, true}, {3, true}, {4, false}};
  aurora::gfx::detail::promote_pending_pipeline(2u, false, background, priority, pending);
  aurora::gfx::detail::promote_pending_pipeline(3u, true, background, priority, pending);
  ASSERT_EQ(priority.size(), 3u);
  EXPECT_EQ(priority[0].hash.value, 3u);
  EXPECT_EQ(priority[1].hash.value, 4u);
  EXPECT_EQ(priority[2].hash.value, 2u);
  ASSERT_EQ(background.size(), 1u);
  EXPECT_EQ(background[0].hash.value, 1u);
}
} // namespace
