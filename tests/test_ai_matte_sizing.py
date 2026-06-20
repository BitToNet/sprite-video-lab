import unittest

from PIL import Image

import server


class AiMatteSizingTests(unittest.TestCase):
    def test_auto_ai_resolution_uses_area_for_wide_images(self):
        image = Image.new("RGBA", (2048, 768))

        self.assertEqual(server.auto_ai_resolution_for_image(image), 1248)

    def test_auto_ai_resolution_preserves_small_image_floor(self):
        image = Image.new("RGBA", (320, 180))

        self.assertEqual(server.auto_ai_resolution_for_image(image), 1024)

    def test_auto_ai_resolution_caps_large_images(self):
        image = Image.new("RGBA", (4096, 4096))

        self.assertEqual(server.auto_ai_resolution_for_image(image), 2560)

    def test_birefnet_input_resize_does_not_letterbox_wide_images(self):
        image = Image.new("RGB", (2048, 768), (210, 20, 30))

        resized = server.resize_birefnet_input(image, 128)

        self.assertEqual(resized.size, (128, 128))
        self.assertEqual(resized.getpixel((0, 0)), (210, 20, 30))
        self.assertEqual(resized.getpixel((127, 0)), (210, 20, 30))
        self.assertEqual(resized.getpixel((0, 127)), (210, 20, 30))
        self.assertEqual(resized.getpixel((127, 127)), (210, 20, 30))

    def test_auto_key_color_uses_dominant_border_color_not_corner_average(self):
        image = Image.new("RGBA", (128, 64), (255, 255, 255, 255))
        for y in range(40, 64):
            for x in range(128):
                image.putpixel((x, y), (35, 40, 45, 255))

        self.assertEqual(server.auto_key_color(image), (255, 255, 255))

    def test_solid_background_fallback_accepts_low_confidence_ai_mask(self):
        image = Image.new("RGBA", (128, 64), (255, 255, 255, 255))
        for y in range(24, 64):
            for x in range(128):
                image.putpixel((x, y), (35, 40, 45, 255))
        ai_score = {
            "max_alpha": 245,
            "mean_alpha": 20.0,
            "visible_ratio": 0.7,
            "strong_ratio": 0.008,
        }

        fallback = server.solid_background_fallback_alpha(image, ai_score, 42, 8)

        self.assertIsNotNone(fallback)
        alpha, info = fallback
        self.assertEqual(info["solid_key_color"], "#FFFFFF")
        self.assertEqual(alpha.getpixel((64, 0)), 0)
        self.assertEqual(alpha.getpixel((64, 63)), 255)


if __name__ == "__main__":
    unittest.main()
