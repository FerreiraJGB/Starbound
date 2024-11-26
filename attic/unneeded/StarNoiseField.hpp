#ifndef STAR_NOISE_FIELD_HPP
#define STAR_NOISE_FIELD_HPP

#include "StarMultiArrayInterpolator.hpp"

namespace Star {

// Noise field with configurable number of layers of randomness.  Each layer of
// randomness is <alpha> times as dense as the last layer, as well as 1.0 /
// <beta> the magnitude of the last layer.  If <alpha> and <beta> are 2.0
// (typical), and there are 4 layers, the perlin field would be constructed as
// follows:
// - The bottom layer would be 1x1, with magnitude 1 / 8
// - Next layer is 2x2 with magnitude 1 / 4
// - Next layer 4x4 with magnitude 1 / 2
// - Top layer 8x8 with magnitude 1.
//
// Note: Cubic interpolation mode *can* produce values just outside the range [0.0, 1.0] when normalized.
template<typename DataT, typename IndexT, typename ScaleT, size_t RankT, typename NoiseSource>
class NoiseField {
public:
  typedef DataT Data;
  static size_t const Rank = RankT;

  typedef IndexT IndexType;
  typedef Array<IndexType, Rank> Index;

  typedef ScaleT ScaleType;
  typedef Array<ScaleType, Rank> Scale;

  typedef Star::MultiArray<Data, Rank> MultiArray;
  typedef typename MultiArray::SizeList Size;

  enum InterpolationMode {
    Linear,
    Smooth,
    Cubic
  };

  NoiseField(InterpolationMode interpolation, size_t minLayer, size_t layers,
      ScaleType alpha = 2.0, ScaleType beta = 2.0, NoiseSource const& noise = NoiseSource())

    : m_minLayer(minLayer), m_noiseSource(noise), m_interpolation(interpolation),
    m_normalize(true), m_max(ScaleType()) {

    m_layers.resize(layers);
    for (size_t i = 0; i < layers; ++i) {
      m_layers[i].indexScale = 1 / pow(alpha, i);
      m_layers[i].valueScale = 1 / pow(beta, layers - i - 1);
      m_max += m_layers[i].valueScale;
    }
  }

  // The maximum scale for any point in the field is sum(1 / s^x, x, 0, n),
  // where s is the layer scale and n is the number of layers.
  // This scale is the maximum amount that a generated value will be relative
  // to the values generated by the noise source.
  //
  // If normalized is set to true, then all values genrated will be divided by
  // this scale, so the range of values generated by this field will always be
  // the same as the range generated by the noise source.
  ScaleType maxScale() const {
    return m_max;
  } 

  InterpolationMode interpolationMode() const {
    return m_interpolation;
  }

  void setInterpolationMode(InterpolationMode interpolation) const {
    m_interpolation = interpolation;
  }

  bool isNormalized() const {
    return m_normalize;
  }

  void setNormalize(bool normalize) {
    m_normalize = normalize;
  }

  MultiArray generate(Index const& min, Size const& size) {
    MultiArray array(size);
    generate(min, array);
    return array;
  }

  void generate(Index const& min, MultiArray& array) {
    Size size = array.size();

    for (size_t i = m_minLayer; i < m_layers.size(); ++i) {
      ScaleType indexScale = m_layers[i].indexScale;
      ScaleType valueScale = m_layers[i].valueScale;

      if (m_normalize)
        valueScale = valueScale / m_max;

      // Bottom layer is always 1x1, so we can skip the resampling step.
      if (i == 0) {
        array.eval(NoiseGenerator(m_noiseSource, i, valueScale, min));
      } else {
        // This layer's min and max index in field space, and the total size of
        // this layer.
        Index layerMinIndex;
        Index layerMaxIndex;
        Size layerSize;

        // Sampling offset of layerMin / layerMax
        Scale sampleMin;
        Scale sampleMax;

        for (size_t j = 0; j < Rank; ++j) {
          ScaleType lmin = min[j] * indexScale;
          ScaleType lmax = (min[j] + size[j] - 1) * indexScale;

          if (m_interpolation == Cubic) {
            layerMinIndex[j] = IndexType(floor(lmin) - 1);
            layerMaxIndex[j] = IndexType(ceil(lmax) + 1);
          } else {
            layerMinIndex[j] = IndexType(floor(lmin));
            layerMaxIndex[j] = IndexType(ceil(lmax));
          }

          layerSize[j] = size_t(layerMaxIndex[j] - layerMinIndex[j]) + 1;
          sampleMin[j] = lmin - layerMinIndex[j];
          sampleMax[j] = lmax - layerMinIndex[j];
        }

        MultiArray layer(layerSize);
        layer.eval(NoiseGenerator(m_noiseSource, i, valueScale, layerMinIndex));

        //TODO: this code isn't even compiled, is it.
        starAssert(m_interpolation != Smooth);
        if (m_interpolation == Cubic) {
          auto interpolator = MultiArrayInterpolator4<MultiArray, ScaleType>(CubicWeightOperator<ScaleType>());
          interpolator.sample(layer, array, sampleMin, sampleMax);
//        } else if (m_interpolation == Smooth) {
//          auto interpolator = MultiArrayInterpolator2<MultiArray, ScaleType>(SmoothWeightOperator<ScaleType>());
//          interpolator.sample(layer, array, sampleMin, sampleMax);
        } else {
          auto interpolator = MultiArrayInterpolator2<MultiArray, ScaleType>(LinearWeightOperator<ScaleType>());
          interpolator.sample(layer, array, sampleMin, sampleMax);
        }
      }
    }
  }

private:
  struct NoiseGenerator {
    NoiseGenerator(NoiseSource& ns, size_t l, ScaleType sc, Index const& mn)
      : noiseSource(ns), layer(l), scale(sc), min(mn) {}

    inline Data operator()(typename MultiArray::IndexList& index) {
      Index loc = min;
      std::transform(min.begin(), min.end(), index.begin(), loc.begin(), std::plus<IndexType>());
      return scale * noiseSource(layer, loc);
    }

    NoiseSource noiseSource;
    size_t layer;
    ScaleType scale;
    Index min;
  };

  struct Layer {
    ScaleType indexScale;
    ScaleType valueScale;
  };

  std::vector<Layer> m_layers;
  size_t m_minLayer;
  NoiseSource m_noiseSource;
  InterpolationMode m_interpolation;
  bool m_normalize;
  Data m_max;
};

// Generates values in range [0.0, 1.0]
struct DoubleNoiseFieldSource {
  DoubleNoiseFieldSource(int64_t s) : seed(s) {}

  template<typename Index>
  inline double operator()(size_t layer, Index const& index) const {
    int64_t x = layer;
    for (size_t i = 0; i < Index::Size; ++i)
      x = x * 38577907 + index[i];

    x = (x<<27) ^ x;
    x *= seed;
    return ((x * (x * x * 5736215731 + 23453458789221) + 1997293021376312589) & 0x7fffffffffffffff) / 9223372036854775808.0;
  }

  int64_t seed;
};

// Generates values in range [0.0, 1.0]
struct FloatNoiseFieldSource {
  FloatNoiseFieldSource(int64_t s) : seed(s) {}

  template<typename Index>
  inline float operator()(size_t layer, Index const& index) const {
    int64_t x = layer;
    for (size_t i = 0; i < Index::Size; ++i)
      x = x * 38577907 + index[i];

    x = (x<<13) ^ x;
    x *= seed;
    return ((x * (x * x * 15731 + 789221) + 1376312589) & 0x7fffffff) / 2147483648.0;
  }

  int64_t seed;
};

}

#endif
