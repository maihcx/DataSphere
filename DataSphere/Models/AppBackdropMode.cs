using System;

namespace DataSphere.Models
{
    /// <summary>
    /// Defines the window background backdrop visual rendering material.
    /// </summary>
    public enum AppBackdropMode
    {
        /// <summary>
        /// Dynamic translucent Mica material matching the desktop wallpaper.
        /// </summary>
        Mica,

        /// <summary>
        /// Tabbed Mica Alt background material optimized for document or tabbed container layouts.
        /// </summary>
        Tabbed,

        /// <summary>
        /// Acrylic material with desktop blur.
        /// </summary>
        Acrylic,

        /// <summary>
        /// Solid opaque background rendering using standard page background theme brushes.
        /// </summary>
        Solid
    }
}
