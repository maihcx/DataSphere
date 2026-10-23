$path = "DataSphere\Controls\SlidingTabIndicatorBehavior.cs"
$text = [System.IO.File]::ReadAllText($path)

$search1 = @"
                        // 2. Animate Background Capsule if present
                        if (bgCapsule != null)
                        {
                            ElementCompositionPreview.SetIsTranslationEnabled(bgCapsule, true);
                            bgCapsule.Opacity = 1.0;
                            Visual capsuleVisual = ElementCompositionPreview.GetElementVisual(bgCapsule);

                            Vector3KeyFrameAnimation bgTranslationAnimation = compositor.CreateVector3KeyFrameAnimation();
"@

$replace1 = @"
                        // 2. Animate Background Capsule if present
                        if (bgCapsule != null)
                        {
                            ElementCompositionPreview.SetIsTranslationEnabled(bgCapsule, true);
                            bgCapsule.Opacity = 1.0;
                            Visual capsuleVisual = ElementCompositionPreview.GetElementVisual(bgCapsule);

                            try
                            {
                                string compInfo = $"[BgCapsule] Name={tabView.Name}, indicator.Compositor={compositor.GetHashCode()}, capsuleVisual.Compositor={capsuleVisual.Compositor.GetHashCode()}, targetBgX={targetBgX}, targetBgY={targetBgY}\n";
                                System.IO.File.AppendAllText(@"C:\Users\huynh\.gemini\antigravity\brain\bed6b624-6a96-45dd-963c-7b8ea009ac6a\debug.log", compInfo);
                            }
                            catch { }

                            Vector3KeyFrameAnimation bgTranslationAnimation = compositor.CreateVector3KeyFrameAnimation();
"@

$search2 = @"
            catch
            {
                indicator.IsVisible = false;
            }
"@

$replace2 = @"
            catch (Exception ex)
            {
                try
                {
                    System.IO.File.AppendAllText(@"C:\Users\huynh\.gemini\antigravity\brain\bed6b624-6a96-45dd-963c-7b8ea009ac6a\debug.log", $"[UpdatePos EXCEPTION] {ex}\n");
                }
                catch { }
                indicator.IsVisible = false;
            }
"@

$text = $text.Replace($search1, $replace1)
$text = $text.Replace($search2, $replace2)
[System.IO.File]::WriteAllText($path, $text)
Write-Host "Updated SlidingTabIndicatorBehavior.cs"
