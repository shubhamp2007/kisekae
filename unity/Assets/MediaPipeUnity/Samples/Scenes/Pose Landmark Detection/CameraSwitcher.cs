using System.Collections;
using Mediapipe.Unity;
using Mediapipe.Unity.Sample;
using Mediapipe.Unity.Sample.PoseLandmarkDetection;
using UnityEngine;

public class CameraSwitcher : MonoBehaviour
{
    public PoseLandmarkerRunner runner;
    public bool startWithFront = true;
    public float startTimeout = 20f;
    public float switchTimeout = 10f;

    bool switching;

    IEnumerator Start()
    {
        if (!startWithFront) yield break;

        float waited = 0f;
        while (waited < startTimeout)
        {
            var s = ImageSourceProvider.ImageSource;
            if (s != null && s.isPrepared && s.isPlaying) break;
            waited += Time.unscaledDeltaTime;
            yield return null;
        }

        var src = ImageSourceProvider.ImageSource;
        if (src == null || !src.isPrepared) yield break;
        if (src.isFrontFacing) yield break;

        int idx = FindIndex(true);
        if (idx >= 0) yield return SwitchRoutine(idx);
    }

    public void SwitchCamera(string unused)
    {
        if (switching) return;
        StartCoroutine(SwitchRoutine(-1));
    }

    [ContextMenu("Test Switch Camera")]
    void TestSwitch()
    {
        SwitchCamera(string.Empty);
    }

    static int FindIndex(bool front)
    {
        var devices = WebCamTexture.devices;
        for (int i = 0; i < devices.Length; i++)
        {
            if (devices[i].isFrontFacing == front) return i;
        }
        return -1;
    }

    IEnumerator SwitchRoutine(int target)
    {
        var src = ImageSourceProvider.ImageSource;
        if (switching || src == null || runner == null) yield break;
        if (!src.isPrepared) yield break;

        int next = target;
        if (next < 0) next = FindIndex(!src.isFrontFacing);
        if (next < 0) yield break;

        switching = true;

        runner.Stop();
        src.Stop();
        yield return null;

        src.SelectSource(next);
        runner.Play();

        float waited = 0f;
        yield return null;
        while (waited < switchTimeout)
        {
            var s = ImageSourceProvider.ImageSource;
            if (s != null && s.isPrepared && s.isPlaying) break;
            waited += Time.unscaledDeltaTime;
            yield return null;
        }

        switching = false;
    }
}