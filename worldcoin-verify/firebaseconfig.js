// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getAnalytics } from "firebase/analytics";
// TODO: Add SDKs for Firebase products that you want to use
// https://firebase.google.com/docs/web/setup#available-libraries

// Your web app's Firebase configuration
// For Firebase JS SDK v7.20.0 and later, measurementId is optional
const firebaseConfig = {
  apiKey: "AIzaSyAUZHEz76igPX1d9KGWYcw_C-DSmrzcbWg",
  authDomain: "strapex-2024.firebaseapp.com",
  projectId: "strapex-2024",
  storageBucket: "strapex-2024.appspot.com",
  messagingSenderId: "729619399085",
  appId: "1:729619399085:web:7d8f78fda212be9df0e124",
  measurementId: "G-GSP01RMCLN"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const analytics = getAnalytics(app);
export const db = getFirestore(app);