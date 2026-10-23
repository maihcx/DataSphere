using System;
using System.Numerics;
using Windows.UI.ViewManagement;

namespace DataSphere.Controls
{
    /// <summary>
    /// Centralized motion configuration and timing definitions for Windows 11 Fluent Design tab and viewport transitions.
    /// Provides consistent easing curves, durations, geometry metrics, and system accessibility detection.
    /// </summary>
    public static class TabMotionConfiguration
    {
        private static readonly UISettings _uiSettings = new();

        /// <summary>
        /// Standard duration for tab viewport entrance transitions (300 milliseconds).
        /// Tuned for comfortable, noticeable spatial continuity across directional view transitions.
        /// </summary>
        public static readonly TimeSpan ContentTransitionDuration = TimeSpan.FromMilliseconds(300);

        /// <summary>
        /// Standard duration for tab header selection indicator and background capsule sliding transitions (250 milliseconds).
        /// </summary>
        public static readonly TimeSpan TabIndicatorDuration = TimeSpan.FromMilliseconds(250);

        /// <summary>
        /// The horizontal translation distance in pixels for directional entrance motion (±32 pixels along the X-axis).
        /// </summary>
        public const float EntranceOffsetX = 32.0f;

        /// <summary>
        /// Legacy vertical translation distance in pixels for entrance motion (+12 pixels along the Y-axis).
        /// Retained for backwards compatibility with non-directional vertical entrance styles.
        /// </summary>
        public const float EntranceOffsetY = 12.0f;

        /// <summary>
        /// Gets or sets a value indicating whether the bottom accent indicator pill is rendered under the active tab.
        /// Defaults to <c>false</c> to present a clean, unencumbered Fluent tab capsule design while preserving background motion.
        /// </summary>
        public static bool IsIndicatorVisible { get; set; } = false;

        /// <summary>
        /// Horizontal inset margin in pixels on each side for the accent selection indicator pill (8 pixels),
        /// ensuring the indicator spans across the tab width without overlapping or clipping the rounded bottom corners.
        /// </summary>
        public const float IndicatorHorizontalInset = 8.0f;

        /// <summary>
        /// Default fallback width in pixels for the compact accent selection pill indicator (20 pixels).
        /// </summary>
        public const float IndicatorWidth = 20.0f;

        /// <summary>
        /// Fixed height in pixels for the compact accent selection pill indicator (3 pixels).
        /// </summary>
        public const float IndicatorHeight = 3.0f;

        /// <summary>
        /// Corner radius in pixels for the compact accent selection pill indicator (1.5 pixels, fully rounded).
        /// </summary>
        public const float IndicatorCornerRadius = 1.5f;

        /// <summary>
        /// Corner radius in pixels for the sliding background capsule (6.0 pixels, matching TabViewItem capsule geometry).
        /// </summary>
        public const float BackgroundCornerRadius = 6.0f;

        /// <summary>
        /// First control point for the Windows 11 Fluent Decelerate cubic-bezier curve (0.1, 0.9).
        /// </summary>
        public static readonly Vector2 DecelerateControlPoint1 = new(0.1f, 0.9f);

        /// <summary>
        /// Second control point for the Windows 11 Fluent Decelerate cubic-bezier curve (0.2, 1.0).
        /// </summary>
        public static readonly Vector2 DecelerateControlPoint2 = new(0.2f, 1.0f);

        /// <summary>
        /// Gets a value indicating whether motion and animation effects are enabled at the operating system level.
        /// Respects the Windows Settings > Accessibility > Visual Effects > Animation effects configuration.
        /// </summary>
        public static bool AreAnimationsEnabled
        {
            get
            {
                try
                {
                    return _uiSettings.AnimationsEnabled;
                }
                catch
                {
                    // Fall back to enabled if UISettings throws in specialized environments.
                    return true;
                }
            }
        }
    }
}
