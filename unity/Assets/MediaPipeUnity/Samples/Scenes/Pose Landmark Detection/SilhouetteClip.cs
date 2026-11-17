using UnityEngine;
using UnityEngine.UI;

public class SilhouetteClip : MonoBehaviour
{
    public RawImage maskImage;
    public Transform searchRoot;
    public bool hideMaskVisual = true;
    public Camera avatarCamera;
    public Shader clipShader;
    public float quadDistance = 0.5f;
    [Range(0.05f, 0.95f)] public float threshold = 0.5f;
    public float dilate = 0.012f;
    public Vector4 channel = new Vector4(0f, 0f, 0f, 1f);
    public bool clipEnabled = true;

    GameObject quad;
    Material material;
    readonly Vector3[] corners = new Vector3[4];

    void Start()
    {
        if (avatarCamera == null)
        {
            Debug.LogError("SilhouetteClip: assign the Avatar Camera.");
            enabled = false;
            return;
        }

        if (clipShader == null) clipShader = Shader.Find("Custom/SilhouetteClip");
        if (clipShader == null)
        {
            Debug.LogError("SilhouetteClip: assign the SilhouetteClip shader in the Inspector.");
            enabled = false;
            return;
        }

        material = new Material(clipShader);

        quad = GameObject.CreatePrimitive(PrimitiveType.Quad);
        quad.name = "SilhouetteQuad";
        var col = quad.GetComponent<Collider>();
        if (col != null) Destroy(col);

        var mr = quad.GetComponent<MeshRenderer>();
        mr.sharedMaterial = material;
        mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
        mr.receiveShadows = false;

        quad.transform.SetParent(avatarCamera.transform, false);
        quad.SetActive(false);
    }

    RawImage FindMask()
    {
        foreach (var r in searchRoot.GetComponentsInChildren<RawImage>(false))
        {
            if (r.texture is Texture2D) return r;
        }
        return null;
    }

    void OnDestroy()
    {
        if (quad != null) Destroy(quad);
        if (material != null) Destroy(material);
    }

    void LateUpdate()
    {
        if (quad == null) return;

        if (maskImage == null && searchRoot != null) maskImage = FindMask();
        if (maskImage != null && hideMaskVisual && maskImage.color.a > 0f) maskImage.color = new Color(1f, 1f, 1f, 0f);

        bool active = clipEnabled && maskImage != null && maskImage.texture != null && maskImage.gameObject.activeInHierarchy;
        if (quad.activeSelf != active) quad.SetActive(active);
        if (!active) return;

        float h = 2f * quadDistance * Mathf.Tan(avatarCamera.fieldOfView * 0.5f * Mathf.Deg2Rad);
        float w = h * avatarCamera.aspect;
        quad.transform.localPosition = new Vector3(0f, 0f, quadDistance);
        quad.transform.localRotation = Quaternion.identity;
        quad.transform.localScale = new Vector3(w * 1.1f, h * 1.1f, 1f);

        Camera canvasCamera = null;
        var canvas = maskImage.canvas;
        if (canvas != null && canvas.renderMode != RenderMode.ScreenSpaceOverlay) canvasCamera = canvas.worldCamera;

        maskImage.rectTransform.GetWorldCorners(corners);
        Vector2 origin = RectTransformUtility.WorldToScreenPoint(canvasCamera, corners[0]);
        Vector2 p1 = RectTransformUtility.WorldToScreenPoint(canvasCamera, corners[1]);
        Vector2 p3 = RectTransformUtility.WorldToScreenPoint(canvasCamera, corners[3]);

        Rect uv = maskImage.uvRect;

        material.SetTexture("_MaskTex", maskImage.texture);
        material.SetVector("_MaskOrigin", new Vector4(origin.x, origin.y, 0f, 0f));
        material.SetVector("_MaskEx", new Vector4(p3.x - origin.x, p3.y - origin.y, 0f, 0f));
        material.SetVector("_MaskEy", new Vector4(p1.x - origin.x, p1.y - origin.y, 0f, 0f));
        material.SetVector("_UVRect", new Vector4(uv.x, uv.y, uv.width, uv.height));
        material.SetVector("_Channel", channel);
        material.SetFloat("_Threshold", threshold);
        material.SetFloat("_Dilate", dilate);
    }
}