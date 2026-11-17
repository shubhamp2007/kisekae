using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.UI;

public class LightMatch : MonoBehaviour
{
    public RectTransform screenRect;
    public RawImage cameraImage;
    public Light keyLight;
    public float interval = 0.4f;
    [Range(0.02f, 1f)] public float smoothing = 0.2f;
    public float ambientScale = 1f;
    public float minKeyIntensity = 0.35f;
    public float maxKeyIntensity = 1.25f;
    [Range(0f, 1f)] public float colorStrength = 0.6f;
    public bool log;

    RenderTexture mid;
    RenderTexture tiny;
    Texture2D readTex;
    float timer;
    bool pending;
    bool hasColor;
    Color smoothed = Color.gray;

    void Start()
    {
        mid = new RenderTexture(64, 64, 0, RenderTextureFormat.ARGB32);
        mid.useMipMap = true;
        mid.autoGenerateMips = true;
        mid.filterMode = FilterMode.Bilinear;
        mid.Create();

        tiny = new RenderTexture(1, 1, 0, RenderTextureFormat.ARGB32);
        tiny.filterMode = FilterMode.Bilinear;
        tiny.Create();

        readTex = new Texture2D(1, 1, TextureFormat.RGBA32, false);

        RenderSettings.ambientMode = AmbientMode.Flat;
    }

    void OnDestroy()
    {
        if (mid != null) mid.Release();
        if (tiny != null) tiny.Release();
    }

    RawImage FindCameraImage()
    {
        if (screenRect == null) return null;
        foreach (var r in screenRect.GetComponentsInChildren<RawImage>(true))
        {
            if (r.texture is WebCamTexture) return r;
        }
        return null;
    }

    void Update()
    {
        timer += Time.deltaTime;
        if (timer < interval || pending) return;
        timer = 0f;

        if (cameraImage == null) cameraImage = FindCameraImage();
        if (cameraImage == null || cameraImage.texture == null) return;

        Graphics.Blit(cameraImage.texture, mid);
        Graphics.Blit(mid, tiny);

        if (SystemInfo.supportsAsyncGPUReadback)
        {
            pending = true;
            AsyncGPUReadback.Request(tiny, 0, TextureFormat.RGBA32, OnReadback);
        }
        else
        {
            var previous = RenderTexture.active;
            RenderTexture.active = tiny;
            readTex.ReadPixels(new Rect(0, 0, 1, 1), 0, 0);
            RenderTexture.active = previous;
            Apply(readTex.GetPixel(0, 0));
        }
    }

    void OnReadback(AsyncGPUReadbackRequest request)
    {
        pending = false;
        if (request.hasError) return;
        var data = request.GetData<Color32>();
        if (data.Length < 1) return;
        Color32 c = data[0];
        Apply(new Color(c.r / 255f, c.g / 255f, c.b / 255f, 1f));
    }

    static float Luma(Color c)
    {
        return c.r * 0.2126f + c.g * 0.7152f + c.b * 0.0722f;
    }

    void Apply(Color average)
    {
        smoothed = hasColor ? Color.Lerp(smoothed, average, smoothing) : average;
        hasColor = true;

        float lum = Mathf.Clamp01(Luma(smoothed));

        RenderSettings.ambientMode = AmbientMode.Flat;
        RenderSettings.ambientLight = smoothed * ambientScale;

        if (keyLight != null)
        {
            keyLight.intensity = Mathf.Lerp(minKeyIntensity, maxKeyIntensity, Mathf.Clamp01(lum * 1.2f));

            Color tint = smoothed / Mathf.Max(lum, 0.05f);
            float peak = Mathf.Max(tint.r, Mathf.Max(tint.g, tint.b));
            if (peak > 1e-4f) tint = new Color(tint.r / peak, tint.g / peak, tint.b / peak, 1f);
            keyLight.color = Color.Lerp(Color.white, tint, colorStrength);
        }

        if (log)
            Debug.Log("LightMatch avg=" + smoothed + " lum=" + lum.ToString("F2"));
    }
}