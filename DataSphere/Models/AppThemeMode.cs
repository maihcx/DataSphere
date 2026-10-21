using System;

namespace DataSphere.Models
{
    /// <summary>
    /// Defines the application visual color theme mode.
    /// </summary>
    public enum AppThemeMode
    {
        /// <summary>
        /// Synchronizes with the current Windows operating system theme (Light or Dark).
        /// </summary>
        Default,

        /// <summary>
        /// Forces the application into Light color theme mode.
        /// </summary>
        Light,

        /// <summary>
        /// Forces the application into Dark color theme mode.
        /// </summary>
        Dark
    }
}
