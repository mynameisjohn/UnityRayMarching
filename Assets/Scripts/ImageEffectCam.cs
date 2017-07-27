using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class ImageEffectCam : MonoBehaviour {
    public Material ImageEffectMat;

    void OnRenderImage(RenderTexture src, RenderTexture dst)
    {
        if (ImageEffectMat != null)
            Graphics.Blit(src, dst, ImageEffectMat);
    }

    // Use this for initialization
    void Start () {
		
	}
	
	// Update is called once per frame
	void Update () {
		
	}
}
