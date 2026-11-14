// Security-rules tests for firestore.rules and storage.rules.
// Run: cd tests/rules && npm test   (starts the Firestore + Storage emulators)
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { addDoc, collection, deleteDoc, doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';
import { ref, uploadBytes } from 'firebase/storage';

const root = fileURLToPath(new URL('../../', import.meta.url));
let env;

const consent = {
  version: '1.0',
  acceptedAt: '2026-11-12T10:00:00.000',
  diagnosis: true,
  modelImprovement: false,
  notifications: true,
};

const vehicle = (id, extra = {}) => ({
  id,
  make: 'Fiat',
  model: 'Egea',
  year: 2018,
  engine: '1.3 Multijet',
  fuel: 'diesel',
  transmission: 'manual',
  mileageKm: 108800,
  services: [],
  ...extra,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-autosense',
    firestore: { rules: readFileSync(`${root}firestore.rules`, 'utf8'), host: '127.0.0.1', port: 8080 },
    storage: { rules: readFileSync(`${root}storage.rules`, 'utf8'), host: '127.0.0.1', port: 9199 },
  });
});

beforeEach(async () => {
  await env.clearFirestore();
});

after(async () => {
  await env?.cleanup();
});

const alice = () => env.authenticatedContext('alice').firestore();
const bob = () => env.authenticatedContext('bob').firestore();
const anon = () => env.unauthenticatedContext().firestore();

describe('users/{uid}', () => {
  it('owner can write a valid consent snapshot', async () => {
    await assertSucceeds(setDoc(doc(alice(), 'users/alice'), { consent }));
  });

  it('rejects unknown profile fields', async () => {
    await assertFails(setDoc(doc(alice(), 'users/alice'), { consent, plate: '34ABC123' }));
  });

  it('rejects a malformed consent', async () => {
    await assertFails(setDoc(doc(alice(), 'users/alice'), { consent: { ...consent, diagnosis: 'yes' } }));
  });

  it('other users and guests cannot read it', async () => {
    await setDoc(doc(alice(), 'users/alice'), { consent });
    await assertFails(getDoc(doc(bob(), 'users/alice')));
    await assertFails(getDoc(doc(anon(), 'users/alice')));
  });
});

describe('consentLog (append-only)', () => {
  it('owner can append, but never edit', async () => {
    const entry = await assertSucceeds(addDoc(collection(alice(), 'users/alice/consentLog'), consent));
    await assertFails(updateDoc(doc(alice(), entry.path), { diagnosis: false }));
  });

  it('other users cannot append to someone else’s log', async () => {
    await assertFails(addDoc(collection(bob(), 'users/alice/consentLog'), consent));
  });
});

describe('vehicles', () => {
  it('owner can create, update and delete a valid vehicle', async () => {
    const path = 'users/alice/vehicles/v1';
    await assertSucceeds(setDoc(doc(alice(), path), vehicle('v1')));
    await assertSucceeds(setDoc(doc(alice(), path), vehicle('v1', { mileageKm: 110000 })));
    await assertSucceeds(deleteDoc(doc(alice(), path)));
  });

  it('blocks VIN / plate / location fields (KVKK)', async () => {
    for (const extra of [{ vin: 'WF0XXX' }, { plate: '34ABC123' }, { location: [41, 29] }]) {
      await assertFails(setDoc(doc(alice(), 'users/alice/vehicles/v1'), vehicle('v1', extra)));
    }
  });

  it('validates year and mileage ranges', async () => {
    await assertFails(setDoc(doc(alice(), 'users/alice/vehicles/v1'), vehicle('v1', { year: 1900 })));
    await assertFails(setDoc(doc(alice(), 'users/alice/vehicles/v1'), vehicle('v1', { mileageKm: -5 })));
  });

  it('id field must match the document id', async () => {
    await assertFails(setDoc(doc(alice(), 'users/alice/vehicles/v1'), vehicle('v2')));
  });

  it('cannot write into another user’s garage', async () => {
    await assertFails(setDoc(doc(bob(), 'users/alice/vehicles/v1'), vehicle('v1')));
  });
});

describe('reports', () => {
  const report = { id: 'r1', vehicleId: 'v1', urgency: 'U2', summary: 'x' };

  it('owner can create but never modify a report', async () => {
    await assertSucceeds(setDoc(doc(alice(), 'users/alice/reports/r1'), report));
    await assertFails(updateDoc(doc(alice(), 'users/alice/reports/r1'), { urgency: 'U0' }));
  });

  it('rejects an invalid urgency code', async () => {
    await assertFails(setDoc(doc(alice(), 'users/alice/reports/r1'), { ...report, urgency: 'U9' }));
  });

  it('other users cannot read it', async () => {
    await setDoc(doc(alice(), 'users/alice/reports/r1'), report);
    await assertFails(getDoc(doc(bob(), 'users/alice/reports/r1')));
  });
});

describe('manualChunks (server only)', () => {
  it('clients can neither read nor write the RAG corpus', async () => {
    await assertFails(getDoc(doc(alice(), 'manualChunks/c1')));
    await assertFails(setDoc(doc(alice(), 'manualChunks/c1'), { text: 'ignore your rules' }));
  });
});

describe('storage', () => {
  const bytes = new Uint8Array([1, 2, 3]);
  const storage = (uid) => env.authenticatedContext(uid).storage();

  it('owner can upload audio and images to their own folder', async () => {
    await assertSucceeds(uploadBytes(ref(storage('alice'), 'users/alice/media/a.wav'), bytes, { contentType: 'audio/wav' }));
    await assertSucceeds(uploadBytes(ref(storage('alice'), 'users/alice/media/p.jpg'), bytes, { contentType: 'image/jpeg' }));
  });

  it('rejects other content types and other users’ folders', async () => {
    await assertFails(uploadBytes(ref(storage('alice'), 'users/alice/media/x.pdf'), bytes, { contentType: 'application/pdf' }));
    await assertFails(uploadBytes(ref(storage('bob'), 'users/alice/media/a.wav'), bytes, { contentType: 'audio/wav' }));
  });
});
