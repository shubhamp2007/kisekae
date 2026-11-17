using UnityEngine;

public class BodyOccluder : MonoBehaviour
{
    public Transform avatarRoot;
    public Shader depthShader;
    public string[] clothKeywords =
    {
        "suit", "shirt", "pant", "trouser", "jacket", "shoe", "boot", "dress",
        "cloth", "casual", "elegant", "coat", "skirt", "sweater", "hoodie", "jean"
    };
    public Renderer[] forceBody;
    public Renderer[] forceClothing;
    public bool logRenderers = true;

    Material depthMaterial;

    void Start()
    {
        if (avatarRoot == null) avatarRoot = transform;

        if (depthShader == null) depthShader = Shader.Find("Custom/DepthMask");
        if (depthShader == null)
        {
            Debug.LogError("BodyOccluder: assign the DepthMask shader in the Inspector.");
            enabled = false;
            return;
        }

        depthMaterial = new Material(depthShader);

        var renderers = avatarRoot.GetComponentsInChildren<Renderer>(true);
        foreach (var r in renderers)
        {
            bool cloth = IsClothing(r);
            if (logRenderers)
                Debug.Log("BodyOccluder: " + r.name + " -> " + (cloth ? "clothing (kept)" : "body (hidden)"));

            if (cloth) continue;

            var mats = new Material[r.sharedMaterials.Length];
            for (int i = 0; i < mats.Length; i++) mats[i] = depthMaterial;
            r.sharedMaterials = mats;
        }
    }

    bool IsClothing(Renderer r)
    {
        if (Contains(forceClothing, r)) return true;
        if (Contains(forceBody, r)) return false;

        if (NameMatches(r.name)) return true;
        foreach (var m in r.sharedMaterials)
        {
            if (m != null && NameMatches(m.name)) return true;
        }
        return false;
    }

    bool NameMatches(string n)
    {
        string lower = n.ToLowerInvariant();
        foreach (var k in clothKeywords)
        {
            if (!string.IsNullOrEmpty(k) && lower.Contains(k.ToLowerInvariant())) return true;
        }
        return false;
    }

    static bool Contains(Renderer[] list, Renderer r)
    {
        if (list == null) return false;
        foreach (var x in list)
        {
            if (x == r) return true;
        }
        return false;
    }
}
