const crypto = require('crypto');
const axios = require('axios');

const LARGE_PRIMES = [224737, 1000639, 2654435761, 2654435769, 1000621, 4294967291];

function str2md5(str) {
  return crypto.createHash('md5').update(str).digest('hex');
}

function getDjb2Mod(str, mod) {
  let hash = mod;
  for (let i = 0; i < str.length; i++) {
    hash = (hash * 33 + str.charCodeAt(i)) & 4294967295;
  }
  return hash;
}

function generateTwoLetterHash(str, prime) {
  const hash = (getDjb2Mod(str, prime) % prime + prime) % prime;
  const first = Math.floor(hash / 26) % 26;
  const second = hash % 26;
  return String.fromCharCode(97 + first, 97 + second);
}

function generateTwoNumberHash(str, prime) {
  const hash = (getDjb2Mod(str, prime) % prime + prime) % prime % 99;
  return String(hash).padStart(2, '0');
}

function createNormalObfuscatedPath(filePath) {
  const cleanPath = filePath.replace(/^\//, '');
  const parts = cleanPath.split('/').filter(Boolean);
  for (let i = 0; i < parts.length; i++) {
    if (i === parts.length - 1) {
      const nameParts = parts[i].split('.');
      nameParts.shift();
      const ext = nameParts.join('.');
      parts[i] = `${str2md5(cleanPath)}.${ext}`;
    } else {
      const hashLetter = generateTwoLetterHash(cleanPath, LARGE_PRIMES[i]);
      const hashNumber = generateTwoNumberHash(cleanPath, LARGE_PRIMES[i]);
      parts[i] = `${hashLetter}-${hashNumber}`;
    }
  }
  return parts.join('/');
}

async function fetchCDNJson(resourcePath) {
  const cdnBase = 'https://sg-tools-cdn.blablalink.com';
  const obfuscated = createNormalObfuscatedPath(resourcePath);
  const fullUrl = `${cdnBase}/${obfuscated}`;
  
  try {
    const res = await axios.get(fullUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko)',
        'Origin': 'https://www.blablalink.com',
        'Referer': 'https://www.blablalink.com/'
      }
    });
    if (res.status === 200) return res.data;
  } catch (e) {}
  return null;
}

module.exports = { fetchCDNJson };
