/* This file provided by Facebook is for non-commercial testing and evaluation
 * purposes only.  Facebook reserves all rights not expressly granted.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * FACEBOOK BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "ViewController.h"

#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import <AsyncDisplayKit/ASAssert.h>
#import <BKDeltaCalculator/BKDeltaCalculator.h>
#import <BKDeltaCalculator/BKDelta.h>

#import "BlurbNode.h"
#import "KittenNode.h"

#define USE_UIKIT 0


static const NSInteger kLitterSize = 5;

@interface ViewController ()
{
#if USE_UIKIT
  UITableView *_tableView;
#else
  ASTableView *_tableView;
#endif

  // array of boxed CGSizes corresponding to placekitten kittens
  NSArray *_kittenDataSource;

  BOOL _dataSourceLocked;
}

@property (nonatomic, strong) NSArray *kittenDataSource;
@property (atomic, assign) BOOL dataSourceLocked;

@end

#if USE_UIKIT
@interface ViewController (UIKit) <UITableViewDataSource, UITableViewDelegate>
@end
#else
@interface ViewController (ASDisplayKit) <ASTableViewDataSource, ASTableViewDelegate>
@end
#endif


@implementation ViewController

#pragma mark -
#pragma mark UIViewController.

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;

#if USE_UIKIT
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"UITableViewCell"];
#else
  _tableView = [[ASTableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain asyncDataFetching:NO];
    // NOTE: (Using Async will cause crash)...
  _tableView.asyncDataSource = self;
  _tableView.asyncDelegate = self;
#endif

  // populate our "data source" with some random kittens

  _kittenDataSource = [self createLitterWithSize:kLitterSize];

  return self;
}

- (NSArray *)createLitterWithSize:(NSInteger)litterSize
{
    NSMutableArray *kittens = [NSMutableArray arrayWithCapacity:litterSize];
    for (NSInteger i = 0; i < litterSize; i++) {
        [kittens addObject:@(i)];
    }
    return kittens;
}

- (NSArray *)createNewLitterFromLitter:(NSArray *)litter {
    NSMutableArray *newLitter = [litter mutableCopy];
    BOOL added = NO;
    while (!added) {
        NSNumber *randomNumber = @(arc4random_uniform(10));
        if (![newLitter containsObject:randomNumber]) {
            [newLitter insertObject:randomNumber atIndex:0];
            added = YES;
        }
    }
    [newLitter removeLastObject];
    return [newLitter copy];
}

- (void)setKittenDataSource:(NSArray *)kittenDataSource {
  ASDisplayNodeAssert(!self.dataSourceLocked, @"Could not update data source when it is locked !");

  _kittenDataSource = kittenDataSource;
}

- (void)viewDidLoad
{
  [super viewDidLoad];

  [self.view addSubview:_tableView];
    
    UIButton *actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    actionButton.backgroundColor = [UIColor redColor];
    actionButton.frame = CGRectMake(100.0, 0.0, 50.0, 44.0);
    [actionButton setTitle:@"Action" forState:UIControlStateNormal];
    [actionButton addTarget:self action:@selector(onAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:actionButton];
}

- (void)viewWillLayoutSubviews
{
  _tableView.frame = self.view.bounds;
}

- (BOOL)prefersStatusBarHidden
{
  return YES;
}

#pragma mark - Helpers

// Clone of to -[BKDelta applyUpdatesToTableView:inSection:withRowAnimation:]
- (void)applyDeltaUpdates:(BKDelta *)delta toTableView:(UITableView *)tableView inSection:(NSUInteger)section withRowAnimation:(UITableViewRowAnimation)rowAnimation {
    NSMutableArray *removedIndexPaths = [NSMutableArray arrayWithCapacity:delta.removedIndices.count];
    [delta.removedIndices enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:idx inSection:section];
        [removedIndexPaths addObject:indexPath];
    }];
    
    [tableView deleteRowsAtIndexPaths:removedIndexPaths withRowAnimation:rowAnimation];
    
    NSMutableArray *addedIndexPaths = [NSMutableArray arrayWithCapacity:delta.addedIndices.count];
    [delta.addedIndices enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:idx inSection:section];
        [addedIndexPaths addObject:indexPath];
    }];
    
    [tableView insertRowsAtIndexPaths:addedIndexPaths withRowAnimation:rowAnimation];
    
    // This will work for UITableView...
    [delta.movedIndexPairs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSNumber *fromIndex = [obj objectAtIndex:0], *toIndex = [obj objectAtIndex:1];
        NSIndexPath *fromIndexPath = [NSIndexPath indexPathForRow:[fromIndex unsignedIntegerValue] inSection:section];
        NSIndexPath *toIndexPath = [NSIndexPath indexPathForRow:[toIndex unsignedIntegerValue] inSection:section];
        [tableView moveRowAtIndexPath:fromIndexPath toIndexPath:toIndexPath];
    }];
}

#pragma mark - Actions

- (void)onAction:(id)sender {
    NSArray *oldDataSource = _kittenDataSource;
    NSArray *newDataSource = [self createNewLitterFromLitter:oldDataSource];
    
    [_tableView beginUpdates];
    BKDeltaCalculator *deltaCalculator = [BKDeltaCalculator deltaCalculatorWithEqualityTest:^BOOL(id a, id b) {
        return [a isEqual:b];
    }];
    BKDelta *delta = [deltaCalculator deltaFromOldArray:oldDataSource toNewArray:newDataSource];
    NSLog(@"Added: %@", delta.addedIndices);
    NSLog(@"Removed: %@", delta.removedIndices);
    NSLog(@"Moved: %@", delta.movedIndexPairs);
    
    _kittenDataSource = newDataSource;
    [self applyDeltaUpdates:delta toTableView:_tableView inSection:0 withRowAnimation:UITableViewRowAnimationFade];
    
    [_tableView endUpdates];
}


#pragma mark -
#pragma mark Kittens.

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSNumber *number = _kittenDataSource[indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"UITableViewCell" forIndexPath:indexPath];
    cell.textLabel.text = number.stringValue;
    return cell;
}

- (ASCellNode *)tableView:(ASTableView *)tableView nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
  NSNumber *number = _kittenDataSource[indexPath.row];
  ASTextCellNode *node = [[ASTextCellNode alloc] init];
  node.text = number.stringValue;
  return node;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  // blurb node + kLitterSize kitties
  return _kittenDataSource.count;
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
  // disable row selection
  return NO;
}

- (void)tableViewLockDataSource:(ASTableView *)tableView
{
  self.dataSourceLocked = YES;
}

- (void)tableViewUnlockDataSource:(ASTableView *)tableView
{
  self.dataSourceLocked = NO;
}

@end
