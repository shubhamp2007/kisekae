// Copyright (c) 2023 homuler
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

using System.Collections;
using Mediapipe.Tasks.Vision.PoseLandmarker;
using UnityEngine;
using UnityEngine.Rendering;

namespace Mediapipe.Unity.Sample.PoseLandmarkDetection
{
  public class PoseLandmarkerRunner : VisionTaskApiRunner<PoseLandmarker>
  {
    [SerializeField] private PoseLandmarkerResultAnnotationController _poseLandmarkerResultAnnotationController;

    private Experimental.TextureFramePool _textureFramePool;

    public readonly PoseLandmarkDetectionConfig config = new PoseLandmarkDetectionConfig();
    public PoseDriver driver;
    static readonly int[] Keys = { 11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28 };
    readonly float[] buf = new float[48];
    readonly float[] wbuf = new float[48];

    private readonly object _pendingLock = new object();
    private PoseLandmarkerResult _pendingResult;
    private bool _hasPending;

    public override void Stop()
    {
      base.Stop();
      _textureFramePool?.Dispose();
      _textureFramePool = null;

      lock (_pendingLock)
      {
        if (_hasPending)
        {
          DisposeAllMasks(_pendingResult);
          _pendingResult = default;
          _hasPending = false;
        }
      }
    }

    private void Update()
    {
      PoseLandmarkerResult result;
      lock (_pendingLock)
      {
        if (!_hasPending) return;
        result = _pendingResult;
        _pendingResult = default;
        _hasPending = false;
      }

      _poseLandmarkerResultAnnotationController.DrawLater(result);
      DisposeAllMasks(result);
    }

    protected override IEnumerator Run()
    {
      config.OutputSegmentationMasks = true;
      config.MinPoseDetectionConfidence = 0.7f;
      config.MinPosePresenceConfidence = 0.7f;
      config.MinTrackingConfidence = 0.7f;
      Debug.Log($"Delegate = {config.Delegate}");
      Debug.Log($"Image Read Mode = {config.ImageReadMode}");
      Debug.Log($"Model = {config.ModelName}");
      Debug.Log($"Running Mode = {config.RunningMode}");
      Debug.Log($"NumPoses = {config.NumPoses}");
      Debug.Log($"MinPoseDetectionConfidence = {config.MinPoseDetectionConfidence}");
      Debug.Log($"MinPosePresenceConfidence = {config.MinPosePresenceConfidence}");
      Debug.Log($"MinTrackingConfidence = {config.MinTrackingConfidence}");
      Debug.Log($"OutputSegmentationMasks = {config.OutputSegmentationMasks}");

      yield return AssetLoader.PrepareAssetAsync(config.ModelPath);

      var options = config.GetPoseLandmarkerOptions(config.RunningMode == Tasks.Vision.Core.RunningMode.LIVE_STREAM ? OnPoseLandmarkDetectionOutput : null);
      taskApi = PoseLandmarker.CreateFromOptions(options, GpuManager.GpuResources);
      var imageSource = ImageSourceProvider.ImageSource;

      yield return imageSource.Play();

      if (!imageSource.isPrepared)
      {
        Logger.LogError(TAG, "Failed to start ImageSource, exiting...");
        yield break;
      }

      // Use RGBA32 as the input format.
      // TODO: When using GpuBuffer, MediaPipe assumes that the input format is BGRA, so maybe the following code needs to be fixed.
      _textureFramePool = new Experimental.TextureFramePool(imageSource.textureWidth, imageSource.textureHeight, TextureFormat.RGBA32, 10);

      // NOTE: The screen will be resized later, keeping the aspect ratio.
      screen.Initialize(imageSource);

      SetupAnnotationController(_poseLandmarkerResultAnnotationController, imageSource);
      _poseLandmarkerResultAnnotationController.InitScreen(imageSource.textureWidth, imageSource.textureHeight);

      var transformationOptions = imageSource.GetTransformationOptions();
      var flipHorizontally = transformationOptions.flipHorizontally;
      var flipVertically = transformationOptions.flipVertically;

      // Always setting rotationDegrees to 0 to avoid the issue that the detection becomes unstable when the input image is rotated.
      // https://github.com/homuler/MediaPipeUnityPlugin/issues/1196
      var imageProcessingOptions = new Tasks.Vision.Core.ImageProcessingOptions(rotationDegrees: 0);

      AsyncGPUReadbackRequest req = default;
      var waitUntilReqDone = new WaitUntil(() => req.done);
      var waitForEndOfFrame = new WaitForEndOfFrame();
      var result = PoseLandmarkerResult.Alloc(options.numPoses, options.outputSegmentationMasks);

      // NOTE: we can share the GL context of the render thread with MediaPipe (for now, only on Android)
      var canUseGpuImage = SystemInfo.graphicsDeviceType == GraphicsDeviceType.OpenGLES3 && GpuManager.GpuResources != null;
      using var glContext = canUseGpuImage ? GpuManager.GetGlContext() : null;

      while (true)
      {
        if (isPaused)
        {
          yield return new WaitWhile(() => isPaused);
        }

        if (!_textureFramePool.TryGetTextureFrame(out var textureFrame))
        {
          yield return new WaitForEndOfFrame();
          continue;
        }

        // Build the input Image
        Image image;
        switch (config.ImageReadMode)
        {
          case ImageReadMode.GPU:
            if (!canUseGpuImage)
            {
              throw new System.Exception("ImageReadMode.GPU is not supported");
            }
            textureFrame.ReadTextureOnGPU(imageSource.GetCurrentTexture(), flipHorizontally, flipVertically);
            image = textureFrame.BuildGPUImage(glContext);
            // TODO: Currently we wait here for one frame to make sure the texture is fully copied to the TextureFrame before sending it to MediaPipe.
            // This usually works but is not guaranteed. Find a proper way to do this. See: https://github.com/homuler/MediaPipeUnityPlugin/pull/1311
            yield return waitForEndOfFrame;
            break;
          case ImageReadMode.CPU:
            yield return waitForEndOfFrame;
            textureFrame.ReadTextureOnCPU(imageSource.GetCurrentTexture(), flipHorizontally, flipVertically);
            image = textureFrame.BuildCPUImage();
            textureFrame.Release();
            break;
          case ImageReadMode.CPUAsync:
          default:
            req = textureFrame.ReadTextureAsync(imageSource.GetCurrentTexture(), flipHorizontally, flipVertically);
            yield return waitUntilReqDone;

            if (req.hasError)
            {
              Debug.LogWarning($"Failed to read texture from the image source");
              continue;
            }
            image = textureFrame.BuildCPUImage();
            textureFrame.Release();
            break;
        }

        switch (taskApi.runningMode)
        {
          case Tasks.Vision.Core.RunningMode.IMAGE:
            if (taskApi.TryDetect(image, imageProcessingOptions, ref result))
            {
              _poseLandmarkerResultAnnotationController.DrawNow(result);
            }
            else
            {
              _poseLandmarkerResultAnnotationController.DrawNow(default);
            }
            DisposeAllMasks(result);
            break;
          case Tasks.Vision.Core.RunningMode.VIDEO:
            if (taskApi.TryDetectForVideo(image, GetCurrentTimestampMillisec(), imageProcessingOptions, ref result))
            {
              _poseLandmarkerResultAnnotationController.DrawNow(result);
            }
            else
            {
              _poseLandmarkerResultAnnotationController.DrawNow(default);
            }
            DisposeAllMasks(result);
            break;
          case Tasks.Vision.Core.RunningMode.LIVE_STREAM:
            taskApi.DetectAsync(image, GetCurrentTimestampMillisec(), imageProcessingOptions);
            break;
        }
      }
    }

    private void OnPoseLandmarkDetectionOutput(PoseLandmarkerResult result, Image image, long timestamp)
    {
      Forward(result);

      var owned = PoseLandmarkerResult.Alloc(config.NumPoses, true);
      result.CloneTo(ref owned);
      if (owned.segmentationMasks != null)
      {
        owned.segmentationMasks.Clear();
        if (result.segmentationMasks != null)
        {
          owned.segmentationMasks.AddRange(result.segmentationMasks);
        }
      }

      lock (_pendingLock)
      {
        if (_hasPending)
        {
          DisposeAllMasks(_pendingResult);
        }
        _pendingResult = owned;
        _hasPending = true;
      }
    }

    private void DisposeAllMasks(PoseLandmarkerResult result)
    {
      if (result.segmentationMasks != null)
      {
        foreach (var mask in result.segmentationMasks)
        {
          mask.Dispose();
        }
      }
    }

    void Forward(PoseLandmarkerResult result)
    {
        if (driver == null || result.poseLandmarks == null || result.poseLandmarks.Count == 0) return;

        var lms = result.poseLandmarks[0].landmarks;
        if (lms == null || lms.Count < 29) return;
        for (int i = 0; i < Keys.Length; i++)
        {
            var lm = lms[Keys[i]];
            buf[i * 4] = lm.x;
            buf[i * 4 + 1] = lm.y;
            buf[i * 4 + 2] = lm.z;
            buf[i * 4 + 3] = lm.visibility ?? 1f;
        }
        driver.Push(buf);

        if (result.poseWorldLandmarks == null || result.poseWorldLandmarks.Count == 0) return;
        var wl = result.poseWorldLandmarks[0].landmarks;
        if (wl == null || wl.Count < 29) return;
        for (int i = 0; i < Keys.Length; i++)
        {
            var lm = wl[Keys[i]];
            wbuf[i * 4] = lm.x;
            wbuf[i * 4 + 1] = lm.y;
            wbuf[i * 4 + 2] = lm.z;
            wbuf[i * 4 + 3] = lm.visibility ?? 1f;
        }
        driver.PushWorld(wbuf);
    }
  }
}