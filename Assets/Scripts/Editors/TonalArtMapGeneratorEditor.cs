using UnityEngine;
using UnityEditor;
using System.Diagnostics;

namespace Scripts.Editors
{

    public class TonalArtMapGeneratorWindow : EditorWindow
    {
        private Texture stroke;
        private Color sourceColor = Color.black;
        private int texturePOTSize = 9;

        private int toneLevels = 8;

        private int mipLevels = 7;
        private float minLength = 0.1f;
        private float maxLength = 0.4f;
        private float minTone = 0.0f;
        private float maxTone = 0.95f;
        private float width = 0.01f;

        private AnimationCurve strokeCurve = new AnimationCurve();

        private float maxBrightnessReduction = 0.8f;
        private bool rotateDark = true;
        private float rotation = 0;
        private float rotationOffset = 3;
        private bool scaleMips = true;

        private string textureName = "TonalArtMapText";

        private string Path => "Assets/Generated/" + textureName + ".asset";
        private bool saveTextures = false;



        [MenuItem("Generators/Tonal Art Map Generator")]
        public static void ShowWindow()
        {
            EditorWindow.GetWindow(typeof(TonalArtMapGeneratorWindow));
        }

        void OnGUI()
        {
            textureName = EditorGUILayout.TextField("Texture Name", textureName);
            stroke = (Texture)EditorGUILayout.ObjectField(
                "Stroke",
                stroke,
                typeof(Texture),
                true,
                GUILayout.Height(EditorGUIUtility.singleLineHeight)
            );

            saveTextures = EditorGUILayout.Toggle("Save textures separately", saveTextures);

            sourceColor = EditorGUILayout.ColorField("Source Color", sourceColor);
            texturePOTSize = EditorGUILayout.IntField("Texture POT Size", texturePOTSize);
            mipLevels = EditorGUILayout.IntField("Mip Levels", mipLevels);
            toneLevels = EditorGUILayout.IntField("Tone Levels", toneLevels);
            // strokeCurve = EditorGUILayout.CurveField("Stroke distribution", strokeCurve);
            minLength = EditorGUILayout.FloatField("Min Length", minLength);
            maxLength = EditorGUILayout.FloatField("Max Length", maxLength);
            width = EditorGUILayout.FloatField("Width", width);
            minTone = EditorGUILayout.FloatField("Min Tone", minTone);
            maxTone = EditorGUILayout.FloatField("Max Tone", maxTone);
            maxBrightnessReduction = EditorGUILayout.FloatField("Max Brightness Reduction", maxBrightnessReduction);
            rotateDark = EditorGUILayout.Toggle("Rotate dark tones", rotateDark);
            rotation = EditorGUILayout.FloatField("Base Rotation", rotation);
            rotationOffset = EditorGUILayout.FloatField("Rotation offset", rotationOffset);
            scaleMips = EditorGUILayout.Toggle("Scale Mips", scaleMips);
            var generate = GUILayout.Button("Generate");

            if (generate)
            {
                var watch = new Stopwatch();
                watch.Start();
                GenerateTonalArtMap();
                watch.Stop();
                var ellapsed = watch.Elapsed;
                UnityEngine.Debug.Log($"{toneLevels}, {mipLevels}, {width}, {ellapsed.TotalMilliseconds * .001}");
            }
        }

        private void GenerateTonalArtMap()
        {
            var gen = new TonalArtMapGenerator(
                texturePOTSize,
                stroke,
                sourceColor,
                toneLevels,
                mipLevels,
                minTone,
                maxTone,
                width,
                maxBrightnessReduction,
                new System.Random(),
                minLength,
                maxLength,
                rotateDark,
                rotation,
                rotationOffset
            );
            
            gen.DrawStrokes();
            // foreach (var _ in gen.DrawStrokes()) { }
            if (saveTextures)
            {
                var textures = gen.GetTextures();
                if (!AssetDatabase.IsValidFolder("Assets/Generated/" + textureName))
                {
                    AssetDatabase.CreateFolder("Assets/Generated", textureName);
                }
                for (int i = 0; i < textures.Count; i++)
                {
                    UnityEditor.AssetDatabase.CreateAsset(textures[i], "Assets/Generated/" + textureName + "/tex" + i + ".asset");
                }
            }

            UnityEditor.AssetDatabase.CreateAsset(gen.GetTextureArray(), Path);
        }
    }
}