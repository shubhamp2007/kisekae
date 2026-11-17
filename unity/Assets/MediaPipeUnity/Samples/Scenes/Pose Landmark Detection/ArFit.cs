using UnityEngine;

public class ArFit : MonoBehaviour
{
    public PoseDriver driver;
    public Transform avatarRoot;
    public RectTransform screenRect;
    public Camera uiCamera;
    public Camera avatarCamera;
    public float minCutoff = 0.5f;
    public float beta = 2f;
    public float minScale = 0.2f;
    public float maxScale = 5f;
    public float hideAfterSeconds = 1.5f;
    public bool logSetup;

    Vector3 hipMidLocal;
    float torsoLength;
    float planeDistance;
    Renderer[] renderers;
    bool[] wasEnabled;
    float lastSeen = -999f;
    bool ready;
    bool shown = true;
    readonly Vector3[] corners = new Vector3[4];
    OneEuroVec3 posFilter;
    OneEuro scaleFilter;

    void Start()
    {
        if (driver == null) driver = GetComponent<PoseDriver>();
        if (avatarRoot == null && driver != null) avatarRoot = driver.transform;

        if (driver == null || avatarRoot == null || screenRect == null || avatarCamera == null)
        {
            Debug.LogError("ArFit: assign Driver, Avatar Root, Screen Rect and Avatar Camera.");
            enabled = false;
            return;
        }

        var animator = driver.animator != null ? driver.animator : avatarRoot.GetComponentInChildren<Animator>();
        if (animator == null || !animator.isHuman)
        {
            Debug.LogError("ArFit: needs a Humanoid Animator under the avatar root.");
            enabled = false;
            return;
        }

        var ls = animator.GetBoneTransform(HumanBodyBones.LeftUpperArm);
        var rs = animator.GetBoneTransform(HumanBodyBones.RightUpperArm);
        var lh = animator.GetBoneTransform(HumanBodyBones.LeftUpperLeg);
        var rh = animator.GetBoneTransform(HumanBodyBones.RightUpperLeg);
        if (ls == null || rs == null || lh == null || rh == null)
        {
            Debug.LogError("ArFit: could not find shoulder and hip bones.");
            enabled = false;
            return;
        }

        Vector3 shoulderMidWorld = (ls.position + rs.position) * 0.5f;
        Vector3 hipMidWorld = (lh.position + rh.position) * 0.5f;

        hipMidLocal = avatarRoot.InverseTransformPoint(hipMidWorld);
        Vector3 shoulderMidLocal = avatarRoot.InverseTransformPoint(shoulderMidWorld);
        torsoLength = Vector3.Distance(shoulderMidLocal, hipMidLocal);
        planeDistance = avatarCamera.transform.InverseTransformPoint(hipMidWorld).z;

        if (torsoLength < 1e-4f || planeDistance <= 0.01f)
        {
            Debug.LogError("ArFit: invalid avatar measurements. Check the avatar camera faces the avatar.");
            enabled = false;
            return;
        }

        renderers = avatarRoot.GetComponentsInChildren<Renderer>(true);
        wasEnabled = new bool[renderers.Length];
        for (int i = 0; i < renderers.Length; i++) wasEnabled[i] = renderers[i].enabled;

        posFilter = new OneEuroVec3(minCutoff, beta);
        scaleFilter = new OneEuro(minCutoff, beta);

        driver.mirror = false;
        ready = true;
        SetShown(false);

        if (logSetup)
            Debug.Log("ArFit torso=" + torsoLength + " planeDistance=" + planeDistance + " hipMidLocal=" + hipMidLocal);
    }

    void SetShown(bool show)
    {
        if (shown == show) return;
        shown = show;
        for (int i = 0; i < renderers.Length; i++)
        {
            if (renderers[i] != null) renderers[i].enabled = show && wasEnabled[i];
        }
    }

    public void RefreshRenderers()
    {
        if (!ready) return;
        var fresh = avatarRoot.GetComponentsInChildren<Renderer>(true);
        var freshWas = new bool[fresh.Length];
        for (int i = 0; i < fresh.Length; i++)
        {
            int idx = System.Array.IndexOf(renderers, fresh[i]);
            if (idx >= 0)
            {
                freshWas[i] = wasEnabled[idx];
            }
            else
            {
                freshWas[i] = true;
                fresh[i].enabled = shown;
            }
        }
        renderers = fresh;
        wasEnabled = freshWas;
    }

    Vector3 UVToWorld(Vector2 uv)
    {
        screenRect.GetWorldCorners(corners);
        Vector3 w = corners[0] + uv.x * (corners[3] - corners[0]) + (1f - uv.y) * (corners[1] - corners[0]);
        Vector2 sp = RectTransformUtility.WorldToScreenPoint(uiCamera, w);
        return avatarCamera.ScreenToWorldPoint(new Vector3(sp.x, sp.y, planeDistance));
    }

    void LateUpdate()
    {
        if (!ready) return;

        float h = screenRect.rect.height;
        if (h > 1f) driver.aspect = screenRect.rect.width / h;
        driver.rotation = Vector3.SignedAngle(Vector3.right, screenRect.right, Vector3.forward);

        Vector2 s0, s1, h0, h1;
        bool ok = driver.TrackingOk
                  && driver.TryGetUV(11, out s0) && driver.TryGetUV(12, out s1)
                  && driver.TryGetUV(23, out h0) && driver.TryGetUV(24, out h1);

        if (ok)
        {
            driver.TryGetUV(11, out s0);
            driver.TryGetUV(12, out s1);
            driver.TryGetUV(23, out h0);
            driver.TryGetUV(24, out h1);

            Vector3 worldShoulder = UVToWorld((s0 + s1) * 0.5f);
            Vector3 worldHip = UVToWorld((h0 + h1) * 0.5f);
            float torso = Vector3.Distance(worldShoulder, worldHip);

            if (torso > 1e-4f)
            {
                if (Time.time - lastSeen > hideAfterSeconds)
                {
                    posFilter.Reset();
                    scaleFilter.Reset();
                }

                posFilter.minCutoff = minCutoff;
                posFilter.beta = beta;
                scaleFilter.minCutoff = minCutoff;
                scaleFilter.beta = beta;

                float target = Mathf.Clamp(torso / torsoLength, minScale, maxScale);
                float s = scaleFilter.Filter(target, Time.time);
                avatarRoot.localScale = Vector3.one * s;

                Vector3 targetPos = worldHip - avatarRoot.rotation * (hipMidLocal * s);
                avatarRoot.position = posFilter.Filter(targetPos, Time.time);

                lastSeen = Time.time;
            }
        }

        SetShown(Time.time - lastSeen < hideAfterSeconds);
    }
}