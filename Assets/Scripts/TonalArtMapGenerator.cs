using UnityEngine;
using System;
using System.Collections.Generic;

namespace Scripts{
public class TonalArtMapGenerator {

		struct Stroke {
			public Vector2 Position;
			public float Length;
			public float Offset;
			public bool Horizontal;

			public override string ToString() {
				return string.Format("Stroke(({0}, {1}), {2}, {3})",
					Position.x,
					Position.y,
					Length,
					Horizontal);
			}
		}

		int potSize;
        private Material reducerMat;
        private Material blendMat;
        int size;
		Texture strokeTex;
        private readonly Color sourceColor;
        private float sourceColorValue;
        int toneLevels;
		int mipLevels;
		float minTone;
		float maxTone;
		float height;
		float minLength;
		float maxLength;
		float maxBrightnessReduction = 0.2f;
		System.Random generator;
		BlueNoise noiseGen;
        private bool rotateDark;
        private readonly float rotation;
        private readonly float rotationOffset;
        Shader blitShader;
		Material bltMat;
		Texture2D toneCalculator;
		Texture2D[] toneCalculators;

		Texture2D[,] MainTextures;

		public RenderTexture[,] Textures { get; private set; }
		public GameObject[,] Planes { get; private set; }

		// TODO this is a nightmare, i should remove all of these
		// things from the constructor and have the user set them
		// manually
		public TonalArtMapGenerator(
				int potSize,
				Texture strokeTex,
				Color sourceColor,
				int toneLevels,
				int mipLevels,
				float minTone,
				float maxTone,
				float height,
				float maxBrightnessReduction,
				System.Random generator,
				float minLength = 0.1f,
				float maxLength = 0.4f,
				bool rotateDark = true,
				float rotation = 0,
				float rotationOffset = 3)
		{
			this.potSize = potSize;
			this.reducerMat = new Material(Shader.Find("Custom/Reducer"));
			this.blendMat = new Material(Shader.Find("Custom/BlendTransparent"));
			this.size = 1 << potSize;
			this.strokeTex = strokeTex;
            this.sourceColor = sourceColor;
            this.sourceColorValue = ColorValue(sourceColor);
            this.toneLevels = toneLevels;
			this.mipLevels = mipLevels;
			this.minTone = minTone;
			this.maxTone = maxTone;
			this.generator = generator;
            this.minLength = minLength;
            this.maxLength = maxLength;
            this.noiseGen = new BlueNoise(generator);
			this.rotateDark = rotateDark;
            this.rotation = rotation;
            this.rotationOffset = rotationOffset;
            this.blitShader = Shader.Find("Custom/StrokeShader");
			this.height = height;
            this.maxBrightnessReduction = maxBrightnessReduction;
            Textures = new RenderTexture[toneLevels, mipLevels];
			MainTextures = new Texture2D[toneLevels, mipLevels];
			Planes = new GameObject[toneLevels, mipLevels];

			toneCalculator = new Texture2D(1, 1, TextureFormat.ARGB32, false);
			toneCalculators = new Texture2D[mipLevels];

			for (int mip = 0; mip < mipLevels; mip++) {
				var mipSize = size >> mip;
				toneCalculators[mip] = new Texture2D(mipSize, mipSize, TextureFormat.ARGB32, true);
			}

			var oldRt = RenderTexture.active;
			for (int tone = 0; tone < toneLevels; tone++) {
				for (int mip = 0; mip < mipLevels; mip++) {
					var mipSize = size >> mip;

					Textures[tone, mip] = new RenderTexture(mipSize, mipSize, 0, RenderTextureFormat.ARGB32);
					Textures[tone, mip].name = string.Format("Tone {0} Mip {1} Size {2}", tone, mip, mipSize);
					Textures[tone, mip].useMipMap = false;
					
					RenderTexture.active = Textures[tone, mip];
					GL.Clear(true, true, new Color(sourceColor.r, sourceColor.g, sourceColor.b, 0));
					
					MainTextures[tone, mip] = new Texture2D(mipSize, mipSize, TextureFormat.ARGB32, false);
					FlushMainTexture(tone, mip);
				}
			}

			RenderTexture.active = oldRt;
		}

		public List<Texture2D> GetTextures() {
			var textures = new List<Texture2D>();
			for(int i = 0; i < this.MainTextures.Length; i++) {
				textures.Add(this.MainTextures[i, 0]);
			}

			return textures;
		}

		public Texture2DArray GetTextureArray() {
			var array = new Texture2DArray(size, size, toneLevels, TextureFormat.ARGB32, mipLevels, true);
			var readingTextures = new Texture2D[mipLevels];

			for (int mip = 0; mip < mipLevels; mip++) {
				var mipSize = size >> mip;
				readingTextures[mip] = new Texture2D(mipSize, mipSize, TextureFormat.ARGB32, false);
			}

			var oldRt = RenderTexture.active;

			for (int tone = 0; tone < toneLevels; tone++) {
				for (int mip = 0; mip < mipLevels; mip++) {
					RenderTexture.active = Textures[tone, mip];

					var mipSize = size >> mip;

					// readingTextures[mip].ReadPixels(new Rect(0, 0, mipSize, mipSize), 0, 0, false);
					var pixels = MainTextures[tone, mip].GetPixels();
					array.SetPixels(pixels, tone, mip);
					// array.SetPixels(pixels, tone, mip);
				}
			}

			array.Apply(false, true);

			array.filterMode = FilterMode.Trilinear;

			RenderTexture.active = oldRt;
			return array;
		}

		public void DrawStrokes() {
			var toneRange = maxTone - minTone;
			var strokes = new Dictionary<(int tone, int mip), List<Stroke>>();
			
			for (int tone = 0; tone < toneLevels; tone++) {
				// // Debug.Log(tone);
				var toneValue = minTone + tone * (toneRange / (toneLevels - 1));

				for (int mip = mipLevels - 1; mip >= 0; mip--) {

					var strokeList = new List<Stroke>();
					strokes[(tone, mip)] = strokeList;

					while (CalculateTone(tone, mip) < toneValue) {
						var stroke = GenerateStroke(toneValue);
						strokeList.Add(stroke);
						ApplyStroke(stroke, tone, mip, rotateDark && toneValue < 0.5f * (maxTone - minTone));
					}
				}
			}

			Debug.Assert(strokes.Count == mipLevels * toneLevels);
		}

		Stroke GenerateStroke(float toneValue) {
			return new Stroke {
				Position	= noiseGen.GetSample(),
				Length		= ShiftDouble(generator.NextDouble(), minLength, maxLength),
				Horizontal	= rotateDark && toneValue < 0.5f * (maxTone - minTone),
				Offset		= rotation + ShiftDouble(generator.NextDouble(), -rotationOffset, rotationOffset),
			};
		}

		float ShiftDouble(double value, float min, float max) {
			return (float)(min + (max - min) * value);
		}

		float ShiftFloat(float value, float o_min, float o_max, float n_min, float n_max) {
			float scale = (n_max - n_min) / (o_max - o_min);
			return n_min + ((value - o_min) * scale);
		}

		void ApplyStroke(Stroke stroke, int toneLevel, int mipLevel, bool horizontal) {
			for (int tone = toneLevel; tone < toneLevels; tone++) {
				for (int mip = mipLevel; mip >= 0; mip--) {
					var toneValue = minTone + tone * ((maxTone - minTone) / (toneLevels - 1));
					DrawStroke(Textures[tone, mip], height * (1 << mip), tone, mip, toneValue, stroke, horizontal);
				}
			}
		}
		
		float CalculateTone(int tone, int mip) {
			var mipSize = size >> mip;
			Debug.Assert(Textures[tone, mip].width == mipSize);
			Debug.Assert(Textures[tone, mip].height == mipSize);
			Debug.Assert(toneCalculators[mip].width == mipSize);
			Debug.Assert(toneCalculators[mip].height == mipSize);

			// toneCalculators[mip].ReadPixels(new Rect(0, 0, mipSize, mipSize), 0, 0, true);
			
			var reductions = Math.Log(mipSize, 2);
			var rtList = new List<RenderTexture>();
			int smallRes = mipSize/2;

			var bigRT = RenderTexture.GetTemporary(MainTextures[tone, mip].width, MainTextures[tone, mip].height, 0, MainTextures[tone, mip].graphicsFormat);
			rtList.Add(bigRT);
			Graphics.CopyTexture(MainTextures[tone, mip], bigRT);

			Graphics.Blit(MainTextures[tone, mip], bigRT, blendMat);
			for (int i = 0; i < reductions; i++)
			{
				var smallRT = RenderTexture.GetTemporary(smallRes, smallRes, 0, bigRT.format);
				rtList.Add(smallRT);
				Graphics.Blit(bigRT,smallRT,reducerMat);
				bigRT = smallRT;
				smallRes >>= 1;
			}

			Debug.Assert(bigRT.width == 1);
			Debug.Assert(bigRT.height == 1);

			var calculator = new Texture2D(1, 1, TextureFormat.ARGB32, false);
			calculator.ReadPixels(new Rect(0, 0, 1, 1), 0, 0, false);
			var col = calculator.GetPixels();

			foreach(var rt in rtList) {
				RenderTexture.ReleaseTemporary(rt);
			}

			Debug.Assert(col.Length == 1);
			// Debug.Log(col[0]);
			// Debug.Log(ShiftFloat(ColorValue(col[0]), 0, sourceColorValue, 0, 1));

			return ShiftFloat(ColorValue(col[0]), 0, sourceColorValue, 0, 1);
		}

		float ColorValue(Color color) {
			var val = color.r * 0.2126f + color.g * 0.7152f + color.b * 0.0722f;

			return 1 - val;
		}

		void FlushMainTexture(int toneLevel, int mip) {
			var oldRt = RenderTexture.active;

			var renderTexture = Textures[toneLevel, mip];
			var mainTexture = MainTextures[toneLevel, mip];
			RenderTexture.active = renderTexture;
			mainTexture.ReadPixels(new Rect(0, 0, renderTexture.width, renderTexture.height), 0, 0, false);
			mainTexture.Apply();

			RenderTexture.active = oldRt;
		}

		void DrawStroke(RenderTexture destination, float height, int toneLevel, int mip, float toneValue, Stroke stroke, bool horizontal)
		{
			if (bltMat == null) {
				bltMat = new Material(blitShader);
			}

			
			float brightnessModifier = ShiftFloat(maxTone - toneValue, minTone, maxTone, 0, maxBrightnessReduction);

			bltMat.SetTexture("_StrokeTex", strokeTex);
			bltMat.SetFloat("_StrokeOffsetX", stroke.Position.x);
			bltMat.SetFloat("_StrokeOffsetY", stroke.Position.y);
			bltMat.SetFloat("_StrokeScaleX", stroke.Length);
			bltMat.SetFloat("_StrokeScaleY", height);
			bltMat.SetFloat("_StrokeRotation", stroke.Offset + (horizontal ? 0 : 90));
			bltMat.SetFloat("_BrightnessRatio", brightnessModifier);

			Graphics.Blit(MainTextures[toneLevel, mip], Textures[toneLevel, mip], bltMat);
			FlushMainTexture(toneLevel, mip);
		}
	}
}