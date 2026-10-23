$content = [System.IO.File]::ReadAllText('DataSphere\Controls\SlidingTabIndicatorBehavior.cs')
[System.IO.File]::WriteAllText('DataSphere\Controls\SlidingTabIndicatorBehavior.cs', ($content.Replace("`r`n", "`n")))
Write-Host "Normalized to LF."
