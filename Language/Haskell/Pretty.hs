-----------------------------------------------------------------------------
-- |
-- Module      :  Language.Haskell.Pretty
-- Copyright   :  (c) The GHC Team, Noel Winstanley 1997-2000
-- License     :  BSD-style (see the file libraries/base/LICENSE)
--
-- Maintainer  :  libraries@haskell.org
-- Stability   :  experimental
-- Portability :  portable
--
-- Pretty printer for Haskell.
--
-----------------------------------------------------------------------------

module Language.Haskell.Pretty (
		-- * Pretty printing
		Pretty,
		prettyPrintWithMode, prettyPrint,
		-- * Pretty-printing modes
		PPHsMode(..), PPLayout(..), defaultMode) where

import Language.Haskell.Syntax

import qualified Text.PrettyPrint as P

infixl 5 $$$

-----------------------------------------------------------------------------

-- | Varieties of layout we can use.
data PPLayout = PPOffsideRule	-- ^ classical layout
	      | PPSemiColon	-- ^ classical layout made explicit
	      | PPInLine	-- ^ inline decls, with newlines between them
	      | PPNoLayout	-- ^ everything on a single line
	      deriving Eq

type Indent = Int

-- | Pretty-printing parameters.
data PPHsMode = PPHsMode {
				-- | indentation of a class or instance
		classIndent :: Indent,
				-- | indentation of a @do@-expression
		doIndent :: Indent,
				-- | indentation of the body of a
				-- @case@ expression
		caseIndent :: Indent,
				-- | indentation of the declarations in a
				-- @let@ expression
		letIndent :: Indent,
				-- | indentation of the declarations in a
				-- @where@ clause
		whereIndent :: Indent,
				-- | indentation added for continuation
				-- lines that would otherwise be offside
		onsideIndent :: Indent,
				-- | blank lines between statements?
		spacing :: Bool,
				-- | Pretty-printing style to use
		layout :: PPLayout,
				-- | add GHC-style @LINE@ pragmas to output?
		linePragmas :: Bool,
				-- | not implemented yet
		comments :: Bool
		}

-- | The default mode: pretty-print using the offside rule and sensible
-- defaults.
defaultMode :: PPHsMode
defaultMode = PPHsMode{
		      classIndent = 8,
		      doIndent = 3,
		      caseIndent = 4,
		      letIndent = 4,
		      whereIndent = 6,
		      onsideIndent = 2,
		      spacing = True,
		      layout = PPOffsideRule,
		      linePragmas = False,
		      comments = True
		      }

-- | Pretty printing monad
newtype DocM s a = DocM (s -> a)

instance Functor (DocM s) where
	 fmap f xs = do x <- xs; return (f x)

instance Monad (DocM s) where
	(>>=) = thenDocM
	(>>) = then_DocM
	return = retDocM

{-# INLINE thenDocM #-}
{-# INLINE then_DocM #-}
{-# INLINE retDocM #-}
{-# INLINE unDocM #-}
{-# INLINE getPPEnv #-}
thenDocM m k = DocM $ (\s -> case unDocM m $ s of a -> unDocM (k a) $ s)
then_DocM m k = DocM $ (\s ->case unDocM m $ s of a ->  unDocM k $ s)
retDocM a = DocM (\s -> a)
unDocM :: DocM s a -> (s -> a)
unDocM (DocM f) = f

-- all this extra stuff, just for this one function.
getPPEnv :: DocM s s
getPPEnv = DocM id

-- So that pp code still looks the same
-- this means we lose some generality though

-- | The document type produced by these pretty printers uses a 'PPHsMode'
-- environment.
type Doc = DocM PPHsMode P.Doc

-- | Things that can be pretty-printed, including all the syntactic objects
-- in "Language.Haskell.Syntax".
class Pretty a where
	-- | Pretty-print something in isolation.
	pretty :: a -> Doc
	-- | Pretty-print something in a precedence context.
	prettyPrec :: Int -> a -> Doc
	pretty = prettyPrec 0
	prettyPrec _ = pretty

-- The pretty printing combinators

empty :: Doc
empty = return P.empty

nest :: Int -> Doc -> Doc
nest i m = m >>= return . P.nest i


-- Literals

text, ptext :: String -> Doc
text = return . P.text
ptext = return . P.text

char :: Char -> Doc
char = return . P.char

int :: Int -> Doc
int = return . P.int

integer :: Integer -> Doc
integer = return . P.integer

float :: Float -> Doc
float = return . P.float

double :: Double -> Doc
double = return . P.double

rational :: Rational -> Doc
rational = return . P.rational

-- Simple Combining Forms

parens, brackets, braces,quotes,doubleQuotes :: Doc -> Doc
parens d = d >>= return . P.parens
brackets d = d >>= return . P.brackets
braces d = d >>= return . P.braces
quotes d = d >>= return . P.quotes
doubleQuotes d = d >>= return . P.doubleQuotes

parensIf :: Bool -> Doc -> Doc
parensIf True = parens
parensIf False = id

-- Constants

semi,comma,colon,space,equals :: Doc
semi = return P.semi
comma = return P.comma
colon = return P.colon
space = return P.space
equals = return P.equals

lparen,rparen,lbrack,rbrack,lbrace,rbrace :: Doc
lparen = return  P.lparen
rparen = return  P.rparen
lbrack = return  P.lbrack
rbrack = return  P.rbrack
lbrace = return  P.lbrace
rbrace = return  P.rbrace

-- Combinators

(<>),(<+>),($$),($+$) :: Doc -> Doc -> Doc
aM <> bM = do{a<-aM;b<-bM;return (a P.<> b)}
aM <+> bM = do{a<-aM;b<-bM;return (a P.<+> b)}
aM $$ bM = do{a<-aM;b<-bM;return (a P.$$ b)}
aM $+$ bM = do{a<-aM;b<-bM;return (a P.$+$ b)}

hcat,hsep,vcat,sep,cat,fsep,fcat :: [Doc] -> Doc
hcat dl = sequence dl >>= return . P.hcat
hsep dl = sequence dl >>= return . P.hsep
vcat dl = sequence dl >>= return . P.vcat
sep dl = sequence dl >>= return . P.sep
cat dl = sequence dl >>= return . P.cat
fsep dl = sequence dl >>= return . P.fsep
fcat dl = sequence dl >>= return . P.fcat

-- Some More

hang :: Doc -> Int -> Doc -> Doc
hang dM i rM = do{d<-dM;r<-rM;return $ P.hang d i r}

-- Yuk, had to cut-n-paste this one from Pretty.hs
punctuate :: Doc -> [Doc] -> [Doc]
punctuate p []     = []
punctuate p (d:ds) = go d ds
                   where
                     go d [] = [d]
                     go d (e:es) = (d <> p) : go e es

-- | render the document with a given mode.
renderWithMode :: PPHsMode -> Doc -> String
renderWithMode ppMode d = P.render . unDocM d $ ppMode

-- | render the document with 'defaultMode'.
render :: Doc -> String
render = renderWithMode defaultMode

-- | pretty-print with a given mode.
prettyPrintWithMode :: Pretty a => PPHsMode -> a -> String
prettyPrintWithMode ppMode = renderWithMode ppMode . pretty

-- | pretty-print with 'defaultMode'.
prettyPrint :: Pretty a => a -> String
prettyPrint = prettyPrintWithMode defaultMode

fullRenderWithMode :: PPHsMode -> P.Mode -> Int -> Float ->
		      (P.TextDetails -> a -> a) -> a -> Doc -> a
fullRenderWithMode ppMode m i f fn e mD =
		   P.fullRender m i f fn e $ (unDocM mD) ppMode


fullRender :: P.Mode -> Int -> Float -> (P.TextDetails -> a -> a)
	      -> a -> Doc -> a
fullRender = fullRenderWithMode defaultMode

-------------------------  Pretty-Print a Module --------------------
instance Pretty HsModule where
	pretty (HsModule pos mod mbExports imp decls) =
		markLine pos $
		topLevel (ppHsModuleHeader mod mbExports)
			 (map pretty imp ++ map pretty decls)

--------------------------  Module Header ------------------------------
ppHsModuleHeader :: Module -> Maybe [HsExportSpec] ->  Doc
ppHsModuleHeader mod mbExportList = mySep [
	text "module",
	pretty mod,
	maybePP (parenList . map pretty) mbExportList,
	text "where"]

instance Pretty Module where
	pretty (Module modName) = text modName

instance Pretty HsExportSpec where
	pretty (HsEVar name)		    = pretty name
	pretty (HsEAbs name)		    = pretty name
	pretty (HsEThingAll name)	    = pretty name <> text "(..)"
	pretty (HsEThingWith name nameList) =
		pretty name <> (parenList . map pretty $ nameList)
	pretty (HsEModuleContents mod)      = text "module" <+> pretty mod

instance Pretty HsImportDecl where
	pretty (HsImportDecl pos mod qual mbName mbSpecs) =
		markLine pos $
		mySep [text "import",
		       if qual then text "qualified" else empty,
		       pretty mod,
		       maybePP (\m -> text "as" <+> pretty m) mbName,
		       maybePP exports mbSpecs]
	    where
		exports (b,specList) =
			if b then text "hiding" <+> specs else specs
		    where specs = parenList . map pretty $ specList

instance Pretty HsImportSpec where
	pretty (HsIVar name)                = pretty name
	pretty (HsIAbs name)                = pretty name
	pretty (HsIThingAll name)           = pretty name <> text "(..)"
	pretty (HsIThingWith name nameList) =
		pretty name <> (parenList . map pretty $ nameList)

-------------------------  Declarations ------------------------------
instance Pretty HsDecl where
	pretty (HsTypeDecl loc name nameList htype) =
		blankline $
		markLine loc $
		mySep ( [text "type", pretty name]
			++ map pretty nameList
			++ [equals, pretty htype])

	pretty (HsDataDecl loc context name nameList constrList derives) =
		blankline $
		markLine loc $
		mySep ( [text "data", ppHsContext context, pretty name]
			++ map pretty nameList)
			<+> (myVcat (zipWith (<+>) (equals : repeat (char '|'))
						   (map pretty constrList))
			$$$ ppHsDeriving derives)

	pretty (HsNewTypeDecl pos context name nameList constr derives) =
		blankline $
		markLine pos $
		mySep ( [text "newtype", ppHsContext context, pretty name]
			++ map pretty nameList)
			<+> equals <+> (pretty constr $$$ ppHsDeriving derives)

	--m{spacing=False}
	-- special case for empty class declaration
	pretty (HsClassDecl pos context name nameList []) =
		blankline $
		markLine pos $
		mySep ( [text "class", ppHsContext context, pretty name]
			++ map pretty nameList)
	pretty (HsClassDecl pos context name nameList declList) =
		blankline $
		markLine pos $
		mySep ( [text "class", ppHsContext context, pretty name]
			++ map pretty nameList ++ [text "where"])
		$$$ body classIndent (map pretty declList)

	-- m{spacing=False}
	-- special case for empty instance declaration
	pretty (HsInstDecl pos context name args []) =
		blankline $
		markLine pos $
		mySep ( [text "instance", ppHsContext context, pretty name]
			++ map ppHsTypeArg args)
	pretty (HsInstDecl pos context name args declList) =
		blankline $
		markLine pos $
		mySep ( [text "instance", ppHsContext context, pretty name]
			++ map ppHsTypeArg args ++ [text "where"])
		$$$ body classIndent (map pretty declList)

	pretty (HsDefaultDecl pos htypes) =
		blankline $
		markLine pos $
		text "default" <+> parenList (map pretty htypes)

	pretty (HsTypeSig pos nameList qualType) =
		blankline $
		markLine pos $
		mySep ((punctuate comma . map pretty $ nameList)
		      ++ [text "::", pretty qualType])

	pretty (HsFunBind matches) =
		foldr ($$$) empty (map pretty matches)

	pretty (HsPatBind pos pat rhs whereDecls) =
		markLine pos $
		myFsep [pretty pat, pretty rhs] $$$ ppWhere whereDecls

	pretty (HsInfixDecl pos assoc prec opList) =
		blankline $
		markLine pos $
		mySep ([pretty assoc, int prec]
		       ++ (punctuate comma . map pretty $ opList))

instance Pretty HsAssoc where
	pretty HsAssocNone  = text "infix"
	pretty HsAssocLeft  = text "infixl"
	pretty HsAssocRight = text "infixr"

instance Pretty HsMatch where
	pretty (HsMatch pos f ps rhs whereDecls) =
		markLine pos $
		myFsep (lhs ++ [pretty rhs])
		$$$ ppWhere whereDecls
	    where
		lhs = case ps of
			l:r:ps' | isSymbolName f ->
				let hd = [pretty l, ppHsName f, pretty r] in
				if null ps' then hd
				else parens (myFsep hd) : map (prettyPrec 2) ps'
			_ -> pretty f : map (prettyPrec 2) ps

ppWhere [] = empty
ppWhere l = nest 2 (text "where" $$$ body whereIndent (map pretty l))

------------------------- Data & Newtype Bodies -------------------------
instance Pretty HsConDecl where
	pretty (HsRecDecl _pos name fieldList) =
		pretty name <> (braceList . map ppField $ fieldList)

	pretty (HsConDecl _pos name@(HsSymbol _) [l, r]) =
		myFsep [pretty l, ppHsName name, pretty r]
	pretty (HsConDecl _pos name typeList) =
		mySep $ ppHsName name : map pretty typeList

ppField :: ([HsName],HsBangType) -> Doc
ppField (names, ty) =
	myFsepSimple $ (punctuate comma . map pretty $ names) ++
		       [text "::", pretty ty]

instance Pretty HsBangType where
	pretty (HsBangedTy ty) = char '!' <> ppHsTypeArg ty
	pretty (HsUnBangedTy ty) = ppHsTypeArg ty

ppHsDeriving :: [HsQName] -> Doc
ppHsDeriving []  = empty
ppHsDeriving [d] = text "deriving" <+> ppHsQName d
ppHsDeriving ds  = text "deriving" <+> parenList (map ppHsQName ds)

------------------------- Types -------------------------
instance Pretty HsQualType where
	pretty (HsQualType context htype) =
		myFsep [ppHsContext context, pretty htype]

ppHsTypeArg :: HsType -> Doc
ppHsTypeArg = prettyPrec 2

-- precedences:
-- 0: top level
-- 1: left argument of ->
-- 2: argument of constructor

instance Pretty HsType where
	prettyPrec p (HsTyFun a b) = parensIf (p > 0) $
		myFsep [prettyPrec 1 a, text "->", pretty b]
	prettyPrec _ (HsTyTuple l) = parenList . map pretty $ l
	prettyPrec p (HsTyApp a b)
		| a == list_tycon = brackets $ pretty b		-- special case
		| otherwise = parensIf (p > 1) $
			myFsep [pretty a, prettyPrec 2 b]
	prettyPrec _ (HsTyVar name) = pretty name
	-- special case
	prettyPrec _ (HsTyCon (Qual mod n)) | mod == prelude_mod = pretty n
	prettyPrec _ (HsTyCon name) = pretty name

------------------------- Expressions -------------------------
instance Pretty HsRhs where
	pretty (HsUnGuardedRhs exp) = equals <+> pretty exp
	pretty (HsGuardedRhss guardList) = myVcat . map pretty $ guardList

instance Pretty HsGuardedRhs where
	pretty (HsGuardedRhs _pos guard body) =
		myFsep [char '|', pretty guard, equals, pretty body]

instance Pretty HsLiteral where
	pretty (HsInt i)        = integer i
	pretty (HsChar c)       = text (show c)
	pretty (HsString s)     = text (show s)
	pretty (HsFrac r)       = double (fromRational r)
	-- GHC unboxed literals:
	pretty (HsCharPrim c)   = text (show c)           <> char '#'
	pretty (HsStringPrim s) = text (show s)           <> char '#'
	pretty (HsIntPrim i)    = integer i               <> char '#'
	pretty (HsFloatPrim r)  = float  (fromRational r) <> char '#'
	pretty (HsDoublePrim r) = double (fromRational r) <> text "##"

instance Pretty HsExp where
	pretty (HsLit l) = pretty l
	-- lambda stuff
	pretty (HsInfixApp a op b) = myFsep [pretty a, pretty op, pretty b]
	pretty (HsNegApp e) = myFsep [char '-', pretty e]
	pretty (HsApp a b) = myFsep [pretty a, pretty b]
	pretty (HsLambda expList body) = myFsep $
		char '\\' : map pretty expList ++ [text "->", pretty body]
	-- keywords
	pretty (HsLet expList letBody) =
		myFsep [text "let" <+> body letIndent (map pretty expList),
			text "in", pretty letBody]
	pretty (HsIf cond thenexp elsexp) =
		myFsep [text "if", pretty cond,
			text "then", pretty thenexp,
			text "else", pretty elsexp]
	pretty (HsCase cond altList) =
		myFsep [text "case", pretty cond, text "of"]
		$$$ body caseIndent (map pretty altList)
	pretty (HsDo stmtList) =
		text "do" $$$ body doIndent (map pretty stmtList)
	-- Constructors & Vars
	pretty (HsVar name) = pretty name
	pretty (HsCon name) = pretty name
	pretty (HsTuple expList) = parenList . map pretty $ expList
	-- weird stuff
	pretty (HsParen exp) = parens . pretty $ exp
	pretty (HsLeftSection exp op) = parens (pretty exp <+> pretty op)
	pretty (HsRightSection op exp) = parens (pretty op <+> pretty exp)
	pretty (HsRecConstr c fieldList) =
		pretty c <> (braceList . map pretty $ fieldList)
	pretty (HsRecUpdate exp fieldList) =
		pretty exp <> (braceList . map pretty $ fieldList)
	-- patterns
	-- special case that would otherwise be buggy
	pretty (HsAsPat name (HsIrrPat exp)) =
		myFsep [pretty name <> char '@', char '~' <> pretty exp]
	pretty (HsAsPat name exp) = hcat [pretty name, char '@', pretty exp]
	pretty HsWildCard = char '_'
	pretty (HsIrrPat exp) = char '~' <> pretty exp
	-- Lists
	pretty (HsList list) =
		bracketList . punctuate comma . map pretty $ list
	pretty (HsEnumFrom exp) =
		bracketList [pretty exp, text ".."]
	pretty (HsEnumFromTo from to) =
		bracketList [pretty from, text "..", pretty to]
	pretty (HsEnumFromThen from thenE) =
		bracketList [pretty from <> comma, pretty thenE]
	pretty (HsEnumFromThenTo from thenE to) =
		bracketList [pretty from <> comma, pretty thenE,
			     text "..", pretty to]
	pretty (HsListComp exp stmtList) =
		bracketList ([pretty exp, char '|']
			     ++ (punctuate comma . map pretty $ stmtList))
	pretty (HsExpTypeSig _pos exp ty) =
		myFsep [pretty exp, text "::", pretty ty]

------------------------- Patterns -----------------------------

instance Pretty HsPat where
	prettyPrec _ (HsPVar name) = pretty name
	prettyPrec _ (HsPLit lit) = pretty lit
	prettyPrec _ (HsPNeg p) = myFsep [char '-', pretty p]
	prettyPrec p (HsPInfixApp a op b) = parensIf (p > 0) $
		myFsep [pretty a, pretty (HsQConOp op), pretty b]
	prettyPrec p (HsPApp n ps) = parensIf (p > 1) $
		myFsep (pretty n : map pretty ps)
	prettyPrec _ (HsPTuple ps) = parenList . map pretty $ ps
	prettyPrec _ (HsPList ps) =
		bracketList . punctuate comma . map pretty $ ps
	prettyPrec _ (HsPParen p) = parens . pretty $ p
	prettyPrec _ (HsPRec c fields) =
		pretty c <> (braceList . map pretty $ fields)
	-- special case that would otherwise be buggy
	prettyPrec _ (HsPAsPat name (HsPIrrPat pat)) =
		myFsep [pretty name <> char '@', char '~' <> pretty pat]
	prettyPrec _ (HsPAsPat name pat) =
		hcat [pretty name, char '@', pretty pat]
	prettyPrec _ HsPWildCard = char '_'
	prettyPrec _ (HsPIrrPat pat) = char '~' <> pretty pat

instance Pretty HsPatField where
	pretty (HsPFieldPat name pat) =
		myFsep [pretty name, equals, pretty pat]

------------------------- Case bodies  -------------------------
instance Pretty HsAlt where
	pretty (HsAlt _pos exp gAlts decls) =
		pretty exp <+> pretty gAlts $$$ ppWhere decls

instance Pretty HsGuardedAlts where
	pretty (HsUnGuardedAlt exp) = text "->" <+> pretty exp
	pretty (HsGuardedAlts altList) = myVcat . map pretty $ altList

instance Pretty HsGuardedAlt where
	pretty (HsGuardedAlt _pos exp body) =
		myFsep [char '|', pretty exp, text "->", pretty body]

------------------------- Statements in monads & list comprehensions -----
instance Pretty HsStmt where
	pretty (HsGenerator exp from) =
		pretty exp <+> text "<-" <+> pretty from
	pretty (HsQualifier exp) = pretty exp
	pretty (HsLetStmt declList) =
		text "let" $$$ body letIndent (map pretty declList)

------------------------- Record updates
instance Pretty HsFieldUpdate where
	pretty (HsFieldUpdate name exp) =
		myFsep [pretty name, equals, pretty exp]

------------------------- Names -------------------------
instance Pretty HsQOp where
	pretty (HsQVarOp n) = ppHsQNameInfix n
	pretty (HsQConOp n) = ppHsQNameInfix n

ppHsQNameInfix :: HsQName -> Doc
ppHsQNameInfix name
	| isSymbolName (getName name) = ppHsQName name
	| otherwise = char '`' <> ppHsQName name <> char '`'

instance Pretty HsQName where
	pretty name = parensIf (isSymbolName (getName name)) (ppHsQName name)

ppHsQName :: HsQName -> Doc
ppHsQName (UnQual name)			= ppHsName name
ppHsQName (Qual mod name)
	| mod == prelude_mod && isSpecialName name = ppHsName name
	| otherwise = pretty mod <> char '.' <> ppHsName name

instance Pretty HsOp where
	pretty (HsVarOp n) = ppHsNameInfix n
	pretty (HsConOp n) = ppHsNameInfix n

ppHsNameInfix :: HsName -> Doc
ppHsNameInfix name
	| isSymbolName name = ppHsName name
	| otherwise = char '`' <> ppHsName name <> char '`'

instance Pretty HsName where
	pretty name = parensIf (isSymbolName name) (ppHsName name)

ppHsName :: HsName -> Doc
ppHsName name = text (show name)

isSymbolName :: HsName -> Bool
isSymbolName (HsSymbol _) = True
isSymbolName _ = False

isSpecialName :: HsName -> Bool
isSpecialName (HsSpecial _) = True
isSpecialName _ = False

getName :: HsQName -> HsName
getName (UnQual s) = s
getName (Qual _ s) = s

ppHsContext :: HsContext -> Doc
ppHsContext []      = empty
ppHsContext context = mySep [parenList (map ppHsAsst context), text "=>"]

-- hacked for multi-parameter type classes

ppHsAsst :: HsAsst -> Doc
ppHsAsst (a,ts) = myFsep (ppHsQName a : map ppHsTypeArg ts)

------------------------- pp utils -------------------------
maybePP :: (a -> Doc) -> Maybe a -> Doc
maybePP pp Nothing = empty
maybePP pp (Just a) = pp a

parenList :: [Doc] -> Doc
parenList = parens . myFsepSimple . punctuate comma

braceList :: [Doc] -> Doc
braceList = braces . myFsepSimple . punctuate comma

bracketList :: [Doc] -> Doc
bracketList = brackets . myFsepSimple

-- Monadic PP Combinators -- these examine the env

blankline :: Doc -> Doc
blankline dl = do{e<-getPPEnv;if spacing e && layout e /= PPNoLayout
			      then space $$ dl else dl}
topLevel :: Doc -> [Doc] -> Doc
topLevel header dl = do
	 e <- fmap layout getPPEnv
	 case e of
	     PPOffsideRule -> header $$ vcat dl
	     PPSemiColon -> header $$ (braces . vcat . punctuate semi) dl
	     PPInLine -> header $$ (braces . vcat . punctuate semi) dl
	     PPNoLayout -> header <+> (braces . hsep . punctuate semi) dl

body :: (PPHsMode -> Int) -> [Doc] -> Doc
body f dl = do
	 e <- fmap layout getPPEnv
	 case e of PPOffsideRule -> indent
		   PPSemiColon   -> indentExplicit
		   _ -> inline
		   where
		   inline = braces . hsep . punctuate semi $ dl
		   indent  = do{i <-fmap f getPPEnv;nest i . vcat $ dl}
		   indentExplicit = do {i <- fmap f getPPEnv;
			   nest i . braces . vcat . punctuate semi $ dl}

($$$) :: Doc -> Doc -> Doc
a $$$ b = layoutChoice (a $$) (a <+>) b

mySep :: [Doc] -> Doc
mySep = layoutChoice mySep' hsep
	where
	-- ensure paragraph fills with indentation.
	mySep' [x]    = x
	mySep' (x:xs) = x <+> fsep xs
	mySep' []     = error "Internal error: mySep"

myVcat :: [Doc] -> Doc
myVcat = layoutChoice vcat hsep

myFsepSimple :: [Doc] -> Doc
myFsepSimple = layoutChoice fsep hsep

-- same, except that continuation lines are indented,
-- which is necessary to avoid triggering the offside rule.
myFsep :: [Doc] -> Doc
myFsep = layoutChoice fsep' hsep
	where	fsep' [] = empty
		fsep' (d:ds) = do
			e <- getPPEnv
			let n = onsideIndent e
			nest n (fsep (nest (-n) d:ds))

layoutChoice a b dl = do e <- getPPEnv
                         if layout e == PPOffsideRule ||
                            layout e == PPSemiColon
                          then a dl else b dl

-- Prefix something with a LINE pragma, if requested.
-- GHC's LINE pragma actually sets the current line number to n-1, so
-- that the following line is line n.  But if there's no newline before
-- the line we're talking about, we need to compensate by adding 1.

markLine :: SrcLoc -> Doc -> Doc
markLine loc doc = do
	e <- getPPEnv
	let y = srcLine loc
	let line l =
	      text ("{-# LINE " ++ show l ++ " \"" ++ srcFilename loc ++ "\" #-}")
	if linePragmas e then layoutChoice (line y $$) (line (y+1) <+>) doc
	      else doc
