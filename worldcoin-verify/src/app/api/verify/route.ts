import { NextResponse, NextRequest } from 'next/server';
import { addDoc, collection } from "firebase/firestore";
import {db} from "../../../../firebaseconfig";
export const config = {
  api: {
    externalResolver: true,
  },
};

export type VerifyReply = {
  code: string;
  detail: string;
};

const verifyEndpoint = `${process.env.NEXT_PUBLIC_WLD_API_BASE_URL}/api/v1/verify/${process.env.NEXT_PUBLIC_WLD_APP_ID}`;

export async function POST(
  req: NextRequest
) {
  const reqBody = await req.json();

  console.log("Received request to verify credential:\n", reqBody);

  const body = {
    nullifier_hash: reqBody.nullifier_hash,
    merkle_root: reqBody.merkle_root,
    proof: reqBody.proof,
    verification_level: reqBody.verification_level,
    action: reqBody.action,
    signal: reqBody.signal,
    walletAddress: reqBody.walletAddress
  };

  console.log("Sending request to World ID /verify endpoint:\n", body);

  const verifyRes = await fetch(verifyEndpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  const wldResponse = await verifyRes.json();

  console.log(
    `Received ${verifyRes.status} response from World ID /verify endpoint:\n`,
    wldResponse
  );

  if (verifyRes.status == 200) {
    console.log(
      "Credential verified! This user's nullifier hash is: ",
      wldResponse.nullifier_hash
    );

    try {
      const docRef = await addDoc(collection(db, "verifiedWallets"), {
        nullifierHash: wldResponse.nullifier_hash,
        walletAddress: reqBody.walletAddress,
      });
      console.log("Stored in Firebase with document ID: ", docRef.id);
    } catch (error) {
      console.error("Error storing in Firebase: ", error);
    }
    
    //Store in firebase here
    return NextResponse.json({
      code: "success",
      detail: "This action verified correctly!",
    });
  } else {
    return NextResponse.json({
      code: wldResponse.code,
      detail: wldResponse.detail,
    });
  }
}

