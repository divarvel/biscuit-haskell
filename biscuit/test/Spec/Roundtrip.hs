{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes       #-}
{-# LANGUAGE RecordWildCards   #-}
module Spec.Roundtrip
  ( specs
  ) where

import           Data.ByteString    (ByteString)
import           Data.List.NonEmpty (NonEmpty ((:|)))
import           Test.Tasty
import           Test.Tasty.HUnit

import           Auth.Biscuit
import           Auth.Biscuit.Token (Biscuit (..))

specs :: TestTree
specs = testGroup "Serde roundtrips"
  [ testGroup "Raw serde"
      [ singleBlock    (serialize, parse)
      , multipleBlocks (serialize, parse)
      ]
  , testGroup "B64 serde"
      [ singleBlock    (serializeB64, parseB64)
      , multipleBlocks (serializeB64, parseB64)
      ]
  , testGroup "Hex serde"
      [ singleBlock    (serializeHex, parseHex)
      , multipleBlocks (serializeHex, parseHex)
      ]
  , testGroup "Keys serde"
      [ private
      , public
      ]
  ]

type Roundtrip = (Biscuit -> ByteString, ByteString -> Either ParseError Biscuit)

roundtrip :: Roundtrip
          -> NonEmpty Block
          -> Assertion
roundtrip (s,p) i@(authority' :| blocks') = do
  let addBlocks bs biscuit = case bs of
        (b:rest) -> addBlocks rest =<< addBlock b biscuit
        []       -> pure biscuit
  keypair <- newKeypair
  init' <- mkBiscuit keypair authority'
  final <- addBlocks blocks' init'
  let serialized = s final
      parsed = p serialized
      getBlocks Biscuit{..} = snd (snd authority) :| (snd . snd <$> blocks)
  getBlocks <$> parsed @?= Right i

singleBlock :: Roundtrip -> TestTree
singleBlock r = testCase "Single block" $ roundtrip r $ pure
  [block|
    right(#authority, "file1", #read);
    right(#authority, "file2", #read);
    right(#authority, "file1", #write);
  |]

multipleBlocks :: Roundtrip -> TestTree
multipleBlocks r = testCase "Multiple block" $ roundtrip r $
    [block|
      right(#authority, "file1", #read);
      right(#authority, "file2", #read);
      right(#authority, "file1", #write);
    |] :|
  [ [block|
      valid_date("file1") <- time(#ambient, $0), resource(#ambient, "file1"), $0 <= 2030-12-31T12:59:59+00:00;
      valid_date($1) <- time(#ambient, $0), resource(#ambient, $1), $0 <= 1999-12-31T12:59:59+00:00, !["file1"].contains($1);
      check if valid_date($0), resource(#ambient, $0);
    |]
  , [block|
      check if true;
      check if !false;
      check if !false;
      check if false or true;
      check if 1 < 2;
      check if 2 > 1;
      check if 1 <= 2;
      check if 1 <= 1;
      check if 2 >= 1;
      check if 2 >= 2;
      check if 3 == 3;
      check if 1 + 2 * 3 - 4 / 2 == 5;
      check if "hello world".starts_with("hello") && "hello world".ends_with("world");
      check if "aaabde".matches("a*c?.e");
      check if "abcD12" == "abcD12";
      check if 2019-12-04T09:46:41+00:00 < 2020-12-04T09:46:41+00:00;
      check if 2020-12-04T09:46:41+00:00 > 2019-12-04T09:46:41+00:00;
      check if 2019-12-04T09:46:41+00:00 <= 2020-12-04T09:46:41+00:00;
      check if 2020-12-04T09:46:41+00:00 >= 2020-12-04T09:46:41+00:00;
      check if 2020-12-04T09:46:41+00:00 >= 2019-12-04T09:46:41+00:00;
      check if 2020-12-04T09:46:41+00:00 >= 2020-12-04T09:46:41+00:00;
      check if 2020-12-04T09:46:41+00:00 == 2020-12-04T09:46:41+00:00;
      check if #abc == #abc;
      check if hex:12ab == hex:12ab;
      check if [1, 2].contains(2);
      check if [2019-12-04T09:46:41+00:00, 2020-12-04T09:46:41+00:00].contains(2020-12-04T09:46:41+00:00);
      check if [false, true].contains(true);
      check if ["abc", "def"].contains("abc");
      check if [hex:12ab, hex:34de].contains(hex:34de);
      check if [#hello, #world].contains(#hello);
    |]
  , [block|
      check if
        resource(#ambient, $0),
        operation(#ambient, #read),
        right(#authority, $0, #read);
    |]
  , [block|
      check if resource(#ambient, "file1");
      check if time(#ambient, $date), $date <= 2018-12-20T00:00:00+00:00;
    |]
  ]

private :: TestTree
private = testGroup "Private key serde"
  [ testCase "Raw bytes" $ do
      pk <- privateKey <$> newKeypair
      parsePrivateKey (serializePrivateKey pk) @?= Just pk
  , testCase "Hex encoding" $ do
      pk <- privateKey <$> newKeypair
      parsePrivateKeyHex (serializePrivateKeyHex pk) @?= Just pk
  ]

public :: TestTree
public = testGroup "Public key serde"
  [ testCase "Raw bytes" $ do
      pk <- publicKey <$> newKeypair
      parsePublicKey (serializePublicKey pk) @?= Just pk
  , testCase "Hex encoding" $ do
      pk <- publicKey <$> newKeypair
      parsePublicKeyHex (serializePublicKeyHex pk) @?= Just pk
  ]
