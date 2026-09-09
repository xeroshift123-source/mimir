'use strict';

const elementsByNameCode = require('./nikkeElements.json');
const { characterOptionTotals, percentileFromHistogram } = require('./nikkeStatistics');
const KEYS = ['Fire', 'Water', 'Wind', 'Electric', 'Iron'];
const ACCOUNT_ELEMENT_ADJUSTED_CACHE_ID = 'account_element_adjusted';

function elementWeight(statistics) {
  const option = statistics.overload?.find(item => item.key === 'elementDamage');
  if (!option) return 0;
  const { adoptionRate: rate, adopterAverageTotalPercent: percent,
    adopterAverageLineCount: lines } = option;
  if (![rate, percent, lines].every(value => Number.isFinite(value) && value >= 0)) return 0;
  const adoptionWeight = rate >= 10 ? 1 : rate >= 5 ? 0.5 : rate >= 3 ? 0.2 : 0.1;
  return percent * lines * adoptionWeight * 0.01;
}

// Retain only numeric inputs for the second calculation phase, never full accounts/UIDs.
function compactElementInvestment(commander) {
  return (Array.isArray(commander?.characters) ? commander.characters : []).flatMap(character => {
    const amount = characterOptionTotals(character).get('elementDamage')?.totalPercent || 0;
    return amount > 0 ? [[Number(character.name_code), amount]] : [];
  });
}

function adjustedTotals(investment, weights) {
  const totals = Object.fromEntries(KEYS.map(key => [key, 0]));
  for (const [code, amount] of investment) {
    for (const key of elementsByNameCode[code] || []) {
      if (Object.hasOwn(totals, key)) totals[key] += amount * (weights[code] || 0);
    }
  }
  return Object.fromEntries(KEYS.map(key => [key, Number(totals[key].toFixed(2))]));
}

function buildAdjustedStatistics(nikkeSnapshots, investments) {
  const weights = Object.fromEntries(nikkeSnapshots
    .filter(snapshot => Number.isInteger(snapshot.data.nameCode))
    .map(snapshot => [snapshot.data.nameCode, elementWeight(snapshot.data)]));
  const elements = KEYS.map(key => ({ key, adjustedAverage: 0, histogram: {} }));
  for (const investment of investments) {
    const totals = adjustedTotals(investment, weights);
    for (const element of elements) {
      const value = totals[element.key];
      element.adjustedAverage += value;
      const bin = value.toFixed(2);
      element.histogram[bin] = (element.histogram[bin] || 0) + 1;
    }
  }
  for (const element of elements) {
    element.adjustedAverage = investments.length
      ? Number((element.adjustedAverage / investments.length).toFixed(2)) : 0;
  }
  return { formulaVersion: 1, sampleCount: investments.length, weights, elements };
}

function attachAdjustedComparison(rawElements, cache, commander) {
  if (cache?.formulaVersion !== 1 || !cache.weights || !Array.isArray(cache.elements)) return rawElements;
  const totals = adjustedTotals(compactElementInvestment(commander), cache.weights);
  return rawElements.map(element => {
    const adjusted = cache.elements.find(item => item.key === element.key);
    if (!adjusted) return element;
    return { ...element, adjustedScore: totals[element.key],
      adjustedAverage: adjusted.adjustedAverage,
      adjustedTopPercent: percentileFromHistogram(adjusted.histogram, totals[element.key]) };
  });
}

module.exports = { ACCOUNT_ELEMENT_ADJUSTED_CACHE_ID, elementWeight,
  compactElementInvestment, adjustedTotals, buildAdjustedStatistics, attachAdjustedComparison };
